defmodule Shinkanki.GameTest do
  use ExUnit.Case, async: true
  alias Shinkanki.Game

  # Helper to create a playing game
  # New scale: F/K/S = 0-10 (initial 5), currency = 10, jaki = 6
  defp playing_game(room_id, attrs \\ %{}) do
    base = %Game{Game.new(room_id) | status: :playing}
    struct(base, attrs)
  end

  describe "new/1" do
    test "creates a new game state with default values" do
      game = Game.new("room_1")
      assert game.room_id == "room_1"
      assert game.turn == 1
      # New rulebook-compliant scale: 0-10
      assert game.forest == 5
      assert game.culture == 5
      assert game.social == 5
      assert game.jaki == 6
      assert game.currency == 10
      # Life Index = F + K + S = 15
      assert game.life_index == 15
      # New games start in :waiting status until started
      assert game.status == :waiting
      # New phase system starts with :hitoyo
      assert game.phase == :hitoyo
    end
  end

  describe "update_stats/2" do
    test "updates stats and recalculates life index" do
      game = playing_game("room_1")
      # Increase forest by 2, decrease culture by 1
      updated_game = Game.update_stats(game, forest: 2, culture: -1)

      assert updated_game.forest == 7
      assert updated_game.culture == 4
      assert updated_game.social == 5
      # Life Index = 7 + 4 + 5 = 16
      assert updated_game.life_index == 16
    end

    test "clamps stats to valid range (0-10)" do
      game = playing_game("room_1")
      # Try to increase forest beyond 10
      updated_game = Game.update_stats(game, forest: 10)
      assert updated_game.forest == 10

      # Try to decrease below 0
      game2 = Game.update_stats(game, forest: -10)
      assert game2.forest == 0
    end

    test "sets status to lost if any stat drops to 0 or below" do
      game = playing_game("room_1")
      # Decrease forest to 0
      lost_game = Game.update_stats(game, forest: -5)

      assert lost_game.forest == 0
      assert lost_game.status == :lost
      assert lost_game.ending_type == :instant_loss
    end
  end

  describe "next_turn/1" do
    test "advances turn" do
      game = playing_game("room_1")
      next_game = Game.next_turn(game)

      assert next_game.turn == 2
    end

    test "does not change state if game is already over" do
      game = %Game{Game.new("room_1") | status: :lost}
      next_game = Game.next_turn(game)
      assert next_game.turn == 1
    end

    @tag :skip
    test "detects win condition after turn 20" do
      # Set up a game at turn 20 with high Life Index
      # New scale: L >= 24 for blessing ending
      %Game{} = base = playing_game("room_1")

      game = %{
        base
        | turn: 20,
          forest: 8,
          culture: 8,
          social: 8,
          life_index: 24,
          event_deck: [],
          event_discard_pile: [],
          phase: :toshiokuri
      }

      # Advance to turn 21 (Game Over check)
      won_game = Game.next_turn(game)

      assert won_game.turn == 21
      assert won_game.status == :won
      assert won_game.ending_type == :blessing
    end

    @tag :skip
    test "detects loss condition after turn 20 if Life Index is low" do
      # Set up a game at turn 20 with low Life Index (< 12)
      %Game{} = base = playing_game("room_1")

      game = %{
        base
        | turn: 20,
          forest: 3,
          culture: 3,
          social: 3,
          life_index: 9,
          event_deck: [],
          event_discard_pile: [],
          phase: :toshiokuri
      }

      # Advance to turn 21
      lost_game = Game.next_turn(game)

      assert lost_game.turn == 21
      assert lost_game.status == :lost
      assert lost_game.ending_type == :lament
    end

    test "standard turn flow works" do
      game = playing_game("room_1")
      next_game = Game.next_turn(game)
      assert next_game.status == :playing
    end
  end

  describe "jaki system" do
    test "jaki affects hitoyo card count" do
      alias Shinkanki.Card
      # jaki 0-2: 1 card
      assert Card.hitoyo_count_for_jaki(0) == 1
      assert Card.hitoyo_count_for_jaki(2) == 1
      # jaki 3-5: 2 cards
      assert Card.hitoyo_count_for_jaki(3) == 2
      assert Card.hitoyo_count_for_jaki(5) == 2
      # jaki 6-8: 3 cards
      assert Card.hitoyo_count_for_jaki(6) == 3
      assert Card.hitoyo_count_for_jaki(8) == 3
    end

    test "jaki is clamped to 0-8" do
      game = playing_game("room_1", %{jaki: 6})
      # Try to increase jaki beyond 8
      updated_game = Game.update_stats(game, %{jaki: 5})
      assert updated_game.jaki == 8

      # Try to decrease below 0
      game2 = Game.update_stats(playing_game("room_1", %{jaki: 2}), %{jaki: -5})
      assert game2.jaki == 0
    end
  end
end
