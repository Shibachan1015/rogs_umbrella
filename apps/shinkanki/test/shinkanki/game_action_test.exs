defmodule Shinkanki.GameActionTest do
  use ExUnit.Case, async: true

  alias Shinkanki.{Card, Game}

  describe "play_action/4" do
    test "player must have card in hand to play" do
      {:ok, game} = Game.new("room") |> Game.join("player_1", "Player One")

      hand = Map.get(game.hands, "player_1")
      [card_id | _] = hand

      assert {:ok, updated_game} = Game.play_action(game, "player_1", card_id, [])
      updated_hand = Map.get(updated_game.hands, "player_1")

      # Card should be consumed and replaced by draw, keeping hand size constant
      assert length(updated_hand) == length(hand)
      assert card_id in updated_game.discard_pile
    end

    test "returns error when card not in hand" do
      {:ok, game} = Game.new("room") |> Game.join("player_1", "Player One")
      hand = Map.get(game.hands, "player_1")

      card_not_in_hand =
        Card.list_actions()
        |> Enum.map(& &1.id)
        |> Enum.find(fn action_id -> action_id not in hand end)

      assert {:error, :card_not_in_hand} =
               Game.play_action(game, "player_1", card_not_in_hand, [])
    end
  end
end
