module Api
  module V1
    class GamesController < ApplicationController
      def show
        game = GameService.find_game_by_id(params[:id])
        if game
          render json: game
        else
          render json: { error: "Game not found" }, status: :not_found
        end
      end
    end
  end
end
