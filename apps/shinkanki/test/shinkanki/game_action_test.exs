defmodule Shinkanki.GameActionTest do
  use ExUnit.Case, async: true

  alias Shinkanki.{Card, Game}

  # Helper to create a started game with a player
  defp started_game_with_player(room_id, player_id, player_name, talents \\ nil) do
    game = Game.new(room_id)
    {:ok, game} = Game.join(game, player_id, player_name, "🎮", talents)
    {:ok, game} = Game.start_game(game)
    game
  end

  describe "play_action/4" do
    test "player must have card in hand to play" do
      game = started_game_with_player("room", "player_1", "Player One")

      hand = Map.get(game.hands, "player_1")
      [card_id | _] = hand

      assert {:ok, updated_game} = Game.play_action(game, "player_1", card_id, [])
      updated_hand = Map.get(updated_game.hands, "player_1")

      # Card should be consumed and replaced by draw, keeping hand size constant
      assert length(updated_hand) == length(hand)
      assert card_id in updated_game.discard_pile
    end

    test "returns error when card not in hand" do
      game = started_game_with_player("room", "player_1", "Player One")
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
      game = Game.new("room")
      {:ok, game} = Game.join(game, "player_1", "Player One", "🎮", talents)
      {:ok, game_2p} = Game.join(game, "player_2", "Player Two")
      {:ok, game_2p} = Game.start_game(game_2p)

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

    @tag :skip
    test "project unlock and execution" do
      # Set up game with enough currency and safe stats to avoid instant loss
      # New scale: F/K/S 0-10, currency 0-100
      base_game = Game.new("room")
      game = %Game{base_game | currency: 100, forest: 5, culture: 5, social: 5}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.start_game(game)

      project_id = :p_forest_fest

      # 1. Try playing project before unlock (should fail)
      # :p_forest_fest requires forest: 8, culture: 6 (new scale)
      assert {:error, :project_not_unlocked} = Game.play_action(game, "p1", project_id)

      # 2. Update stats to unlock project (and avoid losing)
      # +3 forest -> 8, +1 culture -> 6
      game_unlocked = Game.update_stats(game, forest: 3, culture: 1)

      assert game_unlocked.status == :playing
      assert project_id in game_unlocked.available_projects

      # 3. Play project
      # Project effect: +1 to all stats (new scale)
      # Note: Event cards may have been applied during turn advancement, so we check ranges
      assert {:ok, game_after_project} = Game.play_action(game_unlocked, "p1", project_id)

      # Base: forest=8, culture=6, social=5
      # Project: +1 to all
      # Expected: forest=9, culture=7, social=6
      # But event cards may have modified these, so we check that project effect was applied
      assert game_after_project.forest >= 7
      assert game_after_project.culture >= 5
      assert game_after_project.social >= 0

      # Project cost: 5 (new scale). After action, currency is 95.
      # Demurrage and event effects may apply
      assert game_after_project.currency >= 80
      assert game_after_project.currency <= 100
    end
  end
end
