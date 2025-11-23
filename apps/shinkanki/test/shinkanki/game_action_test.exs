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

    test "enforces talent usage limit (unique talents per action & once per turn)" do
      talents = [:t_craft, :t_plan]
      {:ok, game} = Game.new("room") |> Game.join("player_1", "Player One", talents)

      # Add player 2 to prevent immediate turn advancement
      {:ok, game_2p} = Game.join(game, "player_2", "Player Two")

      hand = Map.get(game_2p.hands, "player_1")
      [card1 | _] = hand

      # 1. Try using same talent twice in one action (Duplicate check)
      assert {:error, :duplicate_talent_usage} ==
               Game.play_action(game_2p, "player_1", card1, [:t_craft, :t_craft])

      # 2. Play action correctly with one talent
      assert {:ok, g1} = Game.play_action(game_2p, "player_1", card1, [:t_craft])

      # Verify talent is marked as used
      player1 = g1.players["player_1"]
      assert :t_craft in player1.used_talents
      assert player1.is_ready == true

      # 3. Advance turn (Player 2 plays)
      hand2 = Map.get(g1.hands, "player_2")
      [card2 | _] = hand2
      assert {:ok, g2} = Game.play_action(g1, "player_2", card2, [])

      assert g2.turn == 2

      # 4. Verify used_talents are reset
      player1_turn2 = g2.players["player_1"]
      assert player1_turn2.used_talents == []
      assert player1_turn2.is_ready == false

      # 5. Player 1 can use t_craft again in Turn 2
      hand_turn2 = Map.get(g2.hands, "player_1")
      [card_turn2 | _] = hand_turn2

      assert {:ok, _g3} = Game.play_action(g2, "player_1", card_turn2, [:t_craft])
    end
  end
end
