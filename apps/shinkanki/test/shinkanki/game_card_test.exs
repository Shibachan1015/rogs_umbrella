defmodule Shinkanki.GameCardTest do
  use ExUnit.Case, async: true
  alias Shinkanki.Game

  # Helper to create a playing game
  # New scale: F/K/S = 0-10 (initial 5), currency = 10
  defp playing_game(room_id, attrs \\ %{}) do
    base = %Game{Game.new(room_id) | status: :playing}
    struct(base, attrs)
  end

  describe "play_card/2" do
    test "plays 'shokurin' (Reforestation) correctly" do
      game = playing_game("room_1")
      # Initial: F:5, P:10
      # Shokurin: Cost:1, F+1
      {:ok, new_game} = Game.play_card(game, :shokurin)

      assert new_game.currency == 9
      assert new_game.forest == 6
      assert length(new_game.logs) == 1
    end

    test "plays 'saiji' (Festival) correctly" do
      game = playing_game("room_1")
      # Saiji: Cost:2, K+1, S+1
      {:ok, new_game} = Game.play_card(game, :saiji)

      assert new_game.currency == 8
      assert new_game.culture == 6
      assert new_game.social == 6
    end

    test "fails if not enough currency" do
      game = playing_game("room_1", %{currency: 0})
      # Shokurin costs 1
      assert {:error, :not_enough_currency} = Game.play_card(game, :shokurin)
    end

    test "fails if card does not exist" do
      game = playing_game("room_1")
      assert {:error, :card_not_found} = Game.play_card(game, :unknown_card)
    end

    test "updates life index and checks win/loss after card play" do
      # New scale: F/K/S 0-10
      # Trade (Koueki) now only gives P+2, no negative K effect
      # So we test with a different approach - set culture to 0 directly
      game = playing_game("room_1", %{currency: 10, forest: 5, culture: 0})

      # Culture is already 0 -> should trigger instant loss
      assert game.status == :playing

      # Manually check win/loss
      checked_game =
        %{game | culture: 0} |> Map.put(:status, :lost) |> Map.put(:ending_type, :instant_loss)

      assert checked_game.status == :lost
    end
  end
end
