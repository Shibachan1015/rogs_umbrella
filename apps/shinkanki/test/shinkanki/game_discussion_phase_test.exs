defmodule Shinkanki.GameDiscussionPhaseTest do
  use ExUnit.Case
  alias Shinkanki.Game

  describe "discussion phase management" do
    test "player can mark themselves as ready in discussion phase" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")

      player = Map.get(game.players, "p1")
      assert player.is_ready == false

      {:ok, new_game} = Game.mark_discussion_ready(game, "p1")

      updated_player = Map.get(new_game.players, "p1")
      assert updated_player.is_ready == true

      assert Enum.any?(new_game.logs, fn log ->
               String.contains?(log, "ready for action phase")
             end)
    end

    test "returns error if not in discussion phase" do
      game = %Game{Game.new("room") | phase: :action, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")

      assert {:error, :not_discussion_phase} = Game.mark_discussion_ready(game, "p1")
    end

    test "returns error if player already ready" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Mark first player as ready (should still be in discussion phase)
      {:ok, game} = Game.mark_discussion_ready(game, "p1")
      assert game.phase == :discussion

      # Try to mark same player again - should return error
      assert {:error, :already_ready} = Game.mark_discussion_ready(game, "p1")
    end

    test "advances to action phase when all players are ready" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # First player ready
      {:ok, game} = Game.mark_discussion_ready(game, "p1")
      assert game.phase == :discussion

      # Second player ready - should advance to action phase
      {:ok, final_game} = Game.mark_discussion_ready(game, "p2")
      assert final_game.phase == :action

      assert Enum.any?(final_game.logs, fn log ->
               String.contains?(log, "advancing to action phase")
             end)
    end

    test "single player game advances immediately when ready" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")

      {:ok, final_game} = Game.mark_discussion_ready(game, "p1")
      assert final_game.phase == :action
    end

    test "returns error if player not found" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}

      assert {:error, :player_not_found} = Game.mark_discussion_ready(game, "nonexistent")
    end

    test "returns error if game is over" do
      game = %Game{
        Game.new("room")
        | phase: :discussion,
          status: :won,
          event_deck: [],
          event_discard_pile: []
      }

      assert {:error, :game_over} = Game.mark_discussion_ready(game, "p1")
    end

    test "execute_phase automatically advances when all players ready" do
      game = %Game{Game.new("room") | phase: :discussion, event_deck: [], event_discard_pile: []}
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      # Mark all players as ready manually
      game = %{game | players: Map.update!(game.players, "p1", fn p -> %{p | is_ready: true} end)}
      game = %{game | players: Map.update!(game.players, "p2", fn p -> %{p | is_ready: true} end)}

      # Execute phase should advance to action
      result = Game.next_phase(game)
      assert result.phase == :action
    end
  end
end
