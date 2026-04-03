module GameService
  QUEUE_KEY      = "forca:queue"
  GAME_PREFIX    = "forca:game:"
  PLAYER_PREFIX  = "forca:player:"
  MAX_ERRORS     = 6
  WORDS_FILE     = Rails.root.join("..", "palavras.txt")

  class << self
    def join_queue(player_id)
      words = load_words

      REDIS.hset(player_key(player_id), "status", "queued", "joined_at", Time.now.to_f.to_s)
      REDIS.hdel(player_key(player_id), "game_id")

      opponent_id = REDIS.lpop(QUEUE_KEY)

      if opponent_id.nil? || opponent_id == player_id
        # Put back if same player (shouldn't happen, but safeguard)
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

    def letter_already_tried?(game, letter)
      (game["guessed_letters"] + game["wrong_letters"]).include?(letter)
    end

    def process_guess(game, player_id, letter)
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

    def find_game_by_id(game_id)
      raw = REDIS.hgetall(game_key(game_id))
      return nil if raw.empty?
      deserialize_game(raw)
    end

    def handle_disconnect(player_id)
      REDIS.lrem(QUEUE_KEY, 0, player_id)

      game = find_game_for_player(player_id)
      return unless game
      return if %w[won lost abandoned].include?(game["status"])

      opponent_id = game["player1_id"] == player_id ? game["player2_id"] : game["player1_id"]

      game["status"]    = "abandoned"
      game["winner_id"] = opponent_id
      save_game(game)

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
        message: "Adversário abandonou. Você venceu! 🏆"
      })

      Rails.logger.info "[GameService] Player #{player_id} disconnected from game #{game['game_id']}"
    end

    private

    def create_game(player1_id, player2_id, word)
      game_id = SecureRandom.uuid
      game = {
        "game_id"         => game_id,
        "player1_id"      => player1_id,
        "player2_id"      => player2_id,
        "word"            => word.downcase.strip,
        "guessed_letters" => [],
        "wrong_letters"   => [],
        "current_turn"    => player1_id,
        "status"          => "playing",
        "winner_id"       => nil,
        "created_at"      => Time.now.to_f.to_s
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
        opponent = game["player1_id"] == player_id ? game["player2_id"] : game["player1_id"]
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

      REDIS.hset(game_key(game["game_id"]), data)
      REDIS.expire(game_key(game["game_id"]), 3600)
      game
    end

    def deserialize_game(raw)
      raw["guessed_letters"] = raw["guessed_letters"].to_s.split(",").reject(&:empty?)
      raw["wrong_letters"]   = raw["wrong_letters"].to_s.split(",").reject(&:empty?)
      raw["winner_id"]       = raw["winner_id"].presence
      raw
    end

    def game_key(game_id)
      "#{GAME_PREFIX}#{game_id}"
    end

    def player_key(player_id)
      "#{PLAYER_PREFIX}#{player_id}"
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
