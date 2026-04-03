require "rails_helper"

RSpec.describe GameService, type: :service do
  let(:player1) { "player-test-001" }
  let(:player2) { "player-test-002" }

  before do
    REDIS.del(GameService::QUEUE_KEY)
    REDIS.del("#{GameService::PLAYER_PREFIX}#{player1}")
    REDIS.del("#{GameService::PLAYER_PREFIX}#{player2}")
  end

  after do
    REDIS.del(GameService::QUEUE_KEY)
    REDIS.del("#{GameService::PLAYER_PREFIX}#{player1}")
    REDIS.del("#{GameService::PLAYER_PREFIX}#{player2}")
  end

  describe ".join_queue" do
    context "when no opponent is waiting" do
      it "returns :waiting status" do
        result = GameService.join_queue(player1)
        expect(result[:status]).to eq(:waiting)
      end

      it "adds the player to the queue" do
        GameService.join_queue(player1)
        expect(REDIS.lrange(GameService::QUEUE_KEY, 0, -1)).to include(player1)
      end
    end

    context "when an opponent is waiting" do
      before { GameService.join_queue(player1) }

      it "returns :game_started status" do
        result = GameService.join_queue(player2)
        expect(result[:status]).to eq(:game_started)
      end

      it "returns a game with both players" do
        result = GameService.join_queue(player2)
        game = result[:game]
        expect(game["player1_id"]).to eq(player2)
        expect(game["player2_id"]).to eq(player1)
      end

      it "sets game status to playing" do
        result = GameService.join_queue(player2)
        expect(result[:game]["status"]).to eq("playing")
      end

      it "removes the opponent from the queue" do
        GameService.join_queue(player2)
        expect(REDIS.lrange(GameService::QUEUE_KEY, 0, -1)).not_to include(player1)
      end

      after do
        game_id1 = REDIS.hget("#{GameService::PLAYER_PREFIX}#{player1}", "game_id")
        game_id2 = REDIS.hget("#{GameService::PLAYER_PREFIX}#{player2}", "game_id")
        REDIS.del("#{GameService::GAME_PREFIX}#{game_id1}") if game_id1
        REDIS.del("#{GameService::GAME_PREFIX}#{game_id2}") if game_id2
      end
    end
  end

  describe ".process_guess" do
    let(:game) do
      {
        "game_id"         => "test-game-111",
        "player1_id"      => player1,
        "player2_id"      => player2,
        "word"            => "gato",
        "guessed_letters" => [],
        "wrong_letters"   => [],
        "current_turn"    => player1,
        "status"          => "playing",
        "winner_id"       => nil
      }
    end

    before do
      REDIS.hset("#{GameService::GAME_PREFIX}test-game-111",
        "game_id", "test-game-111",
        "player1_id", player1,
        "player2_id", player2,
        "word", "gato",
        "guessed_letters", "",
        "wrong_letters", "",
        "current_turn", player1,
        "status", "playing",
        "winner_id", ""
      )
    end

    after do
      REDIS.del("#{GameService::GAME_PREFIX}test-game-111")
    end

    context "when guessing a correct letter" do
      it "adds the letter to guessed_letters" do
        updated = GameService.process_guess(game, player1, "g")
        expect(updated["guessed_letters"]).to include("g")
      end

      it "does not add the letter to wrong_letters" do
        updated = GameService.process_guess(game, player1, "g")
        expect(updated["wrong_letters"]).not_to include("g")
      end

      it "switches the turn to the other player" do
        updated = GameService.process_guess(game, player1, "g")
        expect(updated["current_turn"]).to eq(player2)
      end
    end

    context "when guessing a wrong letter" do
      it "adds the letter to wrong_letters" do
        updated = GameService.process_guess(game, player1, "z")
        expect(updated["wrong_letters"]).to include("z")
      end

      it "does not add the letter to guessed_letters" do
        updated = GameService.process_guess(game, player1, "z")
        expect(updated["guessed_letters"]).not_to include("z")
      end
    end

    context "when the word is fully guessed" do
      it "sets status to won and assigns winner" do
        %w[g a t].each { |l| GameService.process_guess(game, player1, l) }
        updated = GameService.process_guess(game, player1, "o")
        expect(updated["status"]).to eq("won")
        expect(updated["winner_id"]).to eq(player1)
      end
    end

    context "when max errors are reached" do
      it "sets status to lost and assigns winner to opponent" do
        %w[b c d e f h].each { |l| GameService.process_guess(game, player1, l) }
        expect(game["status"]).to eq("lost")
        expect(game["winner_id"]).to eq(player2)
      end
    end
  end

  describe ".letter_already_tried?" do
    let(:game) do
      {
        "guessed_letters" => ["a", "b"],
        "wrong_letters"   => ["z"]
      }
    end

    it "returns true for a previously guessed correct letter" do
      expect(GameService.letter_already_tried?(game, "a")).to be true
    end

    it "returns true for a previously guessed wrong letter" do
      expect(GameService.letter_already_tried?(game, "z")).to be true
    end

    it "returns false for a new letter" do
      expect(GameService.letter_already_tried?(game, "c")).to be false
    end
  end
end
