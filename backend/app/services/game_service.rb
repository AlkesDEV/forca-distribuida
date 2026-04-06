module GameService
  QUEUE_KEY                  = "forca:queue"
  GAME_PREFIX                = "forca:game:"
  PLAYER_PREFIX              = "forca:player:"
  DISCONNECT_PREFIX          = "forca:disconnect:"
  MAX_ERRORS                 = 6
  DISCONNECT_GRACE_SECONDS   = 30
  WORDS_FILE                 = Rails.root.join("..", "palavras.txt")

  class << self
    def join_or_resume(player_id)
      existing_game = find_game_for_player(player_id)

      if existing_game && resumable_game?(existing_game, player_id)
        restore_player_connection(player_id, existing_game)
        return { status: :resumed, game: find_game_by_id(existing_game["game_id"]) }
      end

      join_queue(player_id)
    end

    def join_queue(player_id)
      words = load_words

      REDIS.hset(player_key(player_id), "status", "queued", "joined_at", Time.now.to_f.to_s)
      REDIS.hdel(player_key(player_id), "game_id")

      opponent_id = REDIS.lpop(QUEUE_KEY)

      if opponent_id.nil? || opponent_id == player_id
        REDIS.rpush(QUEUE_KEY, opponent_id) if opponent_id == player_id
        REDIS.rpush(QUEUE_KEY, player_id)
        { status: :waiting }
      else
        game = create_game(player_id, opponent_id, words.sample)
        { status: :game_started, game: game }
      end
    end

    def find_game_for_player(player_id)
      game_id = REDIS.hget(player_key(player_id), "game_id")
      return nil unless game_id

      raw = REDIS.hgetall(game_key(game_id))
      return nil if raw.empty?

      deserialize_game(raw)
    end

    def find_game_by_id(game_id)
      raw = REDIS.hgetall(game_key(game_id))
      return nil if raw.empty?

      deserialize_game(raw)
    end

    def letter_already_tried?(game, letter)
      (game["guessed_letters"] + game["wrong_letters"]).include?(letter)
    end

    def process_guess(game, player_id, letter)
      return game unless game["status"] == "playing"

      word = game["word"]
      guessed = game["guessed_letters"]
      wrong = game["wrong_letters"]

      if word.include?(letter)
        guessed << letter
        game["guessed_letters"] = guessed
      else
        wrong << letter
        game["wrong_letters"] = wrong
      end

      game = check_game_over(game, player_id)

      unless %w[won lost].include?(game["status"])
        other = game["player1_id"] == player_id ? game["player2_id"] : game["player1_id"]
        game["current_turn"] = other
      end

      save_game(game)
      game
    end

    def handle_disconnect(player_id)
      REDIS.lrem(QUEUE_KEY, 0, player_id)

      game = find_game_for_player(player_id)
      return unless game
      return if %w[won lost abandoned].include?(game["status"])

      deadline = Time.now.to_i + DISCONNECT_GRACE_SECONDS

      REDIS.hset(
        disconnect_key(player_id),
        "game_id", game["game_id"],
        "deadline", deadline.to_s
      )
      REDIS.expire(disconnect_key(player_id), DISCONNECT_GRACE_SECONDS + 5)

      game["status"] = "reconnecting"
      game["disconnected_player_id"] = player_id
      game["disconnect_deadline"] = deadline.to_s
      save_game(game)

      opponent_id = opponent_for(game, player_id)

      ActionCable.server.broadcast("player_#{opponent_id}", {
        type: "game_state",
        game_id: game["game_id"],
        player_id: opponent_id,
        opponent_id: player_id,
        revealed_word: build_revealed_word(game),
        word_length: game["word"].length,
        guessed_letters: game["guessed_letters"],
        wrong_letters: game["wrong_letters"],
        wrong_count: game["wrong_letters"].length,
        max_errors: MAX_ERRORS,
        is_my_turn: false,
        status: "reconnecting",
        winner_id: nil,
        message: "Adversário desconectado. Aguardando reconexão por 30s..."
      })

      Thread.new do
        sleep DISCONNECT_GRACE_SECONDS
        finalize_disconnect(player_id, game["game_id"])
      end

      Rails.logger.info "[GameService] Player #{player_id} disconnected from game #{game['game_id']}, waiting #{DISCONNECT_GRACE_SECONDS}s"
    end

    def restore_player_connection(player_id, game)
      REDIS.del(disconnect_key(player_id))

      if game["disconnected_player_id"] == player_id && game["status"] == "reconnecting"
        game["status"] = "playing"
        game["disconnected_player_id"] = nil
        game["disconnect_deadline"] = nil
        save_game(game)

        opponent_id = opponent_for(game, player_id)

        ActionCable.server.broadcast("player_#{opponent_id}", {
          type: "game_state",
          game_id: game["game_id"],
          player_id: opponent_id,
          opponent_id: player_id,
          revealed_word: build_revealed_word(game),
          word_length: game["word"].length,
          guessed_letters: game["guessed_letters"],
          wrong_letters: game["wrong_letters"],
          wrong_count: game["wrong_letters"].length,
          max_errors: MAX_ERRORS,
          is_my_turn: game["current_turn"] == opponent_id,
          status: "playing",
          winner_id: game["winner_id"],
          message: "Adversário reconectado. Partida retomada."
        })
      end

      REDIS.hset(player_key(player_id), "status", "playing")
    end

    private

    def finalize_disconnect(player_id, game_id)
      disconnect_data = REDIS.hgetall(disconnect_key(player_id))
      return if disconnect_data.empty?
      return unless disconnect_data["game_id"] == game_id

      game = find_game_by_id(game_id)
      return unless game
      return unless game["status"] == "reconnecting"
      return unless game["disconnected_player_id"] == player_id

      opponent_id = opponent_for(game, player_id)

      game["status"] = "abandoned"
      game["winner_id"] = opponent_id
      save_game(game)

      REDIS.del(disconnect_key(player_id))

      ActionCable.server.broadcast("player_#{opponent_id}", {
        type: "game_state",
        game_id: game["game_id"],
        player_id: opponent_id,
        opponent_id: player_id,
        revealed_word: game["word"].chars,
        word_length: game["word"].length,
        guessed_letters: game["guessed_letters"],
        wrong_letters: game["wrong_letters"],
        wrong_count: game["wrong_letters"].length,
        max_errors: MAX_ERRORS,
        is_my_turn: false,
        status: "abandoned",
        winner_id: opponent_id,
        message: "Adversário não reconectou em 30s. Você venceu! 🏆"
      })

      Rails.logger.info "[GameService] Player #{player_id} did not reconnect in time for game #{game_id}"
    end

    def resumable_game?(game, player_id)
      game &&
        %w[playing reconnecting].include?(game["status"]) &&
        [game["player1_id"], game["player2_id"]].include?(player_id)
    end

    def create_game(player1_id, player2_id, word)
      game_id = SecureRandom.uuid
      game = {
        "game_id"               => game_id,
        "player1_id"            => player1_id,
        "player2_id"            => player2_id,
        "word"                  => word.downcase.strip,
        "guessed_letters"       => [],
        "wrong_letters"         => [],
        "current_turn"          => player1_id,
        "status"                => "playing",
        "winner_id"             => nil,
        "disconnected_player_id"=> nil,
        "disconnect_deadline"   => nil,
        "created_at"            => Time.now.to_f.to_s
      }

      save_game(game)
      REDIS.hset(player_key(player1_id), "game_id", game_id, "status", "playing")
      REDIS.hset(player_key(player2_id), "game_id", game_id, "status", "playing")

      Rails.logger.info "[GameService] Game #{game_id} created: #{player1_id} vs #{player2_id}, word=#{word}"
      game
    end

    def check_game_over(game, player_id)
      word    = game["word"]
      guessed = game["guessed_letters"]
      wrong   = game["wrong_letters"]

      if word.chars.uniq.all? { |c| guessed.include?(c) }
        game["status"]    = "won"
        game["winner_id"] = player_id
      elsif wrong.length >= MAX_ERRORS
        opponent = opponent_for(game, player_id)
        game["status"]    = "lost"
        game["winner_id"] = opponent
      end

      game
    end

    def save_game(game)
      data = game.dup
      data["guessed_letters"] = data["guessed_letters"].join(",")
      data["wrong_letters"]   = data["wrong_letters"].join(",")
      data["winner_id"]       = data["winner_id"].to_s
      data["disconnected_player_id"] = data["disconnected_player_id"].to_s
      data["disconnect_deadline"] = data["disconnect_deadline"].to_s

      REDIS.hset(game_key(game["game_id"]), data)
      REDIS.expire(game_key(game["game_id"]), 3600)
      game
    end

    def deserialize_game(raw)
      raw["guessed_letters"] = raw["guessed_letters"].to_s.split(",").reject(&:empty?)
      raw["wrong_letters"]   = raw["wrong_letters"].to_s.split(",").reject(&:empty?)
      raw["winner_id"]       = raw["winner_id"].presence
      raw["disconnected_player_id"] = raw["disconnected_player_id"].presence
      raw["disconnect_deadline"] = raw["disconnect_deadline"].presence
      raw
    end

    def build_revealed_word(game)
      word = game["word"]
      guessed = game["guessed_letters"] || []
      word.chars.map { |c| guessed.include?(c) ? c : "_" }
    end

    def opponent_for(game, player_id)
      game["player1_id"] == player_id ? game["player2_id"] : game["player1_id"]
    end

    def game_key(game_id)
      "#{GAME_PREFIX}#{game_id}"
    end

    def player_key(player_id)
      "#{PLAYER_PREFIX}#{player_id}"
    end

    def disconnect_key(player_id)
      "#{DISCONNECT_PREFIX}#{player_id}"
    end

    def load_words
      path = WORDS_FILE
      if File.exist?(path)
        File.readlines(path).map(&:strip).reject(&:empty?)
      else
        %w[programacao distribuido algoritmo servidor tecnologia]
      end
    end
  end
end