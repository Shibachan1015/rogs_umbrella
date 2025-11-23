defmodule Shinkanki.GameCardTest do
  use ExUnit.Case, async: true
  alias Shinkanki.Game

  describe "play_card/2" do
    test "plays 'shokurin' (Reforestation) correctly" do
      game = Game.new("room_1")
      # Initial: F:50, P:100
      # Shokurin: Cost:10, F+5
      {:ok, new_game} = Game.play_card(game, :shokurin)

      assert new_game.currency == 90
      assert new_game.forest == 55
      assert length(new_game.logs) == 1
    end

    test "plays 'saiji' (Festival) correctly" do
      game = Game.new("room_1")
      # Saiji: Cost:20, K+5, S+3
      {:ok, new_game} = Game.play_card(game, :saiji)

      assert new_game.currency == 80
      assert new_game.culture == 55
      assert new_game.social == 53
    end

    test "fails if not enough currency" do
      game = %Game{Game.new("room_1") | currency: 5}
      # Shokurin costs 10
      assert {:error, :not_enough_currency} = Game.play_card(game, :shokurin)
    end

    test "fails if card does not exist" do
      game = Game.new("room_1")
      assert {:error, :card_not_found} = Game.play_card(game, :unknown_card)
    end

    test "updates life index and checks win/loss after card play" do
      # Start with low stats close to losing
      game = %Game{Game.new("room_1") | currency: 100, forest: 5}

      # Play Trade (Koueki): Cost:10, P+20, K-5
      # If K is 50 (default), K becomes 45. Not a loss.
      {:ok, %Game{} = game1} = Game.play_card(game, :koueki)
      assert game1.culture == 45
      assert game1.status == :playing

      # Set Culture to 5 to force loss on next Trade
      game2 = %Game{game1 | culture: 5}
      {:ok, game3} = Game.play_card(game2, :koueki) # K becomes 0

      assert game3.culture == 0
      assert game3.status == :lost
    end
  end
end
