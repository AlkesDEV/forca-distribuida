module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :player_id

    def connect
      self.player_id = request.params[:player_id] || SecureRandom.uuid
      logger.info "[Cable] Player connected: #{player_id}"
    end

    def disconnect
      logger.info "[Cable] Player disconnected: #{player_id}"
      GameService.handle_disconnect(player_id)
    end
  end
end
