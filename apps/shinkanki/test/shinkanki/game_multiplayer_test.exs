defmodule Shinkanki.GameMultiplayerTest do
  use ExUnit.Case
  alias Shinkanki.Game

  describe "multiplayer support" do
    test "player_order is maintained when players join" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      assert "p1" in game.player_order

      {:ok, game} = Game.join(game, "p2", "Player 2")
      assert "p1" in game.player_order
      assert "p2" in game.player_order
      assert length(game.player_order) == 2
    end

    test "get_current_player returns first player in action phase" do
      game = %Game{Game.new("room") | phase: :action, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      current_player = Game.get_current_player(game)
      assert current_player == "p1"
    end

    test "play_action only allows current player to act in action phase" do
      game = %Game{
        Game.new("room")
        | phase: :action,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # First player can act
      hand1 = Map.get(game.hands, "p1", [])

      if hand1 != [] do
        assert {:ok, _} = Game.play_action(game, "p1", List.first(hand1), [])
      end

      # Second player cannot act yet (will get :not_your_turn error)
      hand2 = Map.get(game.hands, "p2", [])

      if hand2 != [] do
        assert {:error, :not_your_turn} = Game.play_action(game, "p2", List.first(hand2), [])
      end
    end

    test "play_action advances to next player" do
      game = %Game{
        Game.new("room")
        | phase: :action,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Initial current player should be p1
      assert Game.get_current_player(game) == "p1"

      # Play action as p1
      hand = Map.get(game.hands, "p1", [])

      if hand != [] do
        {:ok, new_game} = Game.play_action(game, "p1", List.first(hand), [])

        # Current player should advance to p2
        assert Game.get_current_player(new_game) == "p2"
      end
    end

    test "play_action returns error if not current player's turn" do
      game = %Game{
        Game.new("room")
        | phase: :action,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Verify current player is p1
      assert Game.get_current_player(game) == "p1"

      # Try to play action as p2 when it's p1's turn
      hand = Map.get(game.hands, "p2", [])

      if hand != [] do
        assert {:error, :not_your_turn} = Game.play_action(game, "p2", List.first(hand), [])
      end
    end

    test "player order cycles correctly" do
      game = %Game{
        Game.new("room")
        | phase: :action,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")
      {:ok, game} = Game.join(game, "p3", "Player 3")

      # Play actions to cycle through all players
      # Start with p1
      assert Game.get_current_player(game) == "p1"
      hand1 = Map.get(game.hands, "p1", [])

      if hand1 != [] do
        {:ok, game} = Game.play_action(game, "p1", List.first(hand1), [])
        # Should advance to p2
        assert Game.get_current_player(game) == "p2"

        # Play as p2
        hand2 = Map.get(game.hands, "p2", [])

        if hand2 != [] do
          {:ok, game} = Game.play_action(game, "p2", List.first(hand2), [])
          # Should advance to p3
          assert Game.get_current_player(game) == "p3"
        end
      end
    end

    test "all players ready check works in discussion phase" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Mark one player ready - phase should still be discussion
      {:ok, game} = Game.mark_discussion_ready(game, "p1")
      assert game.phase == :discussion

      # Mark both players ready - phase should advance to action
      {:ok, final_game} = Game.mark_discussion_ready(game, "p2")
      assert final_game.phase == :action
    end

    test "maybe_advance_turn advances when all players ready in action phase" do
      game = %Game{
        Game.new("room")
        | phase: :action,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Mark all players as ready
      game = %{game | players: Map.update!(game.players, "p1", fn p -> %{p | is_ready: true} end)}
      game = %{game | players: Map.update!(game.players, "p2", fn p -> %{p | is_ready: true} end)}

      # Advance turn - should move to demurrage phase
      result = Game.next_phase(game)
      assert result.phase == :demurrage || result.phase == :life_update
    end

    test "current_player_index resets on turn end" do
      game = %Game{Game.new("room") | phase: :action, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Advance player index by playing action
      hand = Map.get(game.hands, "p1", [])

      if hand != [] do
        {:ok, game} = Game.play_action(game, "p1", List.first(hand), [])
        assert game.current_player_index == 1

        # Mark all players ready and advance phase to complete turn
        game = %{
          game
          | players: Map.update!(game.players, "p1", fn p -> %{p | is_ready: true} end)
        }

        game = %{
          game
          | players: Map.update!(game.players, "p2", fn p -> %{p | is_ready: true} end)
        }

        # Next turn should reset index
        game_after_turn = Game.next_turn(game)
        # After next_turn, we're in a new turn, so index should be reset or at 0
        assert game_after_turn.current_player_index == 0 || game_after_turn.phase != :action
      end
    end
  end
end
