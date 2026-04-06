class GameChannel < ApplicationCable::Channel
  def subscribed
  player_id = connection.player_id
  stream_from "player_#{player_id}"

  result = GameService.join_or_resume(player_id)

  case result[:status]
  when :waiting
    transmit({
      type: "waiting",
      message: "Aguardando adversário...",
      player_id: player_id
    })
  when :game_started, :resumed
    game = result[:game]
    broadcast_game_state(game)
  end
end

  def unsubscribed
    # handled in Connection#disconnect
  end

  def guess_letter(data)
  player_id = connection.player_id
  letter = data["letter"]&.downcase&.strip

  return unless letter&.match?(/\A[a-z]\z/)

  game = GameService.find_game_for_player(player_id)
  return transmit({ type: "error", message: "Jogo não encontrado." }) unless game
  return transmit({ type: "error", message: "Partida pausada aguardando reconexão do adversário." }) unless game["status"] == "playing"
  return transmit({ type: "error", message: "Não é sua vez!" }) unless game["current_turn"] == player_id
  return transmit({ type: "error", message: "Letra já tentada!" }) if GameService.letter_already_tried?(game, letter)

  updated_game = GameService.process_guess(game, player_id, letter)
  broadcast_game_state(updated_game)
end

  private

  def broadcast_game_state(game)
    players = [game["player1_id"], game["player2_id"]]
    players.each do |pid|
      next unless pid
      ActionCable.server.broadcast("player_#{pid}", build_state(game, pid))
    end
  end

  def build_state(game, player_id)
    is_my_turn = game["current_turn"] == player_id
    opponent_id = game["player1_id"] == player_id ? game["player2_id"] : game["player1_id"]
    word = game["word"]
    guessed = game["guessed_letters"] || []
    wrong = game["wrong_letters"] || []
    revealed = word.chars.map { |c| guessed.include?(c) ? c : "_" }

    status_msg = case game["status"]
             when "waiting" then "Aguardando adversário..."
             when "playing" then is_my_turn ? "Sua vez! Escolha uma letra." : "Vez do adversário..."
             when "reconnecting"
               if game["disconnected_player_id"] == player_id
                 "Reconectado. Retomando partida..."
               else
                 "Adversário desconectado. Aguardando reconexão..."
               end
             when "won"  then game["winner_id"] == player_id ? "Você venceu! 🎉" : "Você perdeu. 😢"
             when "lost" then game["winner_id"] == player_id ? "Você venceu! 🎉" : "Você perdeu. 😢"
             when "abandoned" then "Adversário abandonou. Você venceu! 🏆"
             else "..."
             end

    {
      type: "game_state",
      game_id: game["game_id"],
      player_id: player_id,
      opponent_id: opponent_id,
      revealed_word: revealed,
      word_length: word.length,
      guessed_letters: guessed,
      wrong_letters: wrong,
      wrong_count: wrong.length,
      max_errors: 6,
      is_my_turn: is_my_turn,
      status: game["status"],
      winner_id: game["winner_id"],
      message: status_msg
    }
  end

  def ping(data)
  player_id = connection.player_id
  sent_at = data["sent_at"]

  Rails.logger.info "[GameChannel] Ping received from player=#{player_id} sent_at=#{sent_at}"

  transmit({
    type: "pong",
    sent_at: sent_at,
    server_time: (Time.now.to_f * 1000).to_i
  })
end

end
