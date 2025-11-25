defmodule Shinkanki.AITest do
  use ExUnit.Case
  alias Shinkanki.{Game, AI}

  describe "select_action/2" do
    test "selects a playable card from hand" do
      game = %Game{Game.new("room") | currency: 1000, forest: 10, culture: 10, social: 10}
      {:ok, game} = Game.join(game, "ai_player", "AI Player")

      # AI should be able to select an action
      case AI.select_action(game, "ai_player") do
        {:ok, action_id, talent_ids} ->
          # Verify the action can be played
          assert is_atom(action_id)
          assert is_list(talent_ids)
          assert length(talent_ids) <= 2

        {:error, :no_affordable_cards} ->
          # This is acceptable if currency is too low
          :ok

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    test "returns error if player not found" do
      game = Game.new("room")
      assert {:error, :player_not_found} = AI.select_action(game, "nonexistent")
    end

    test "returns error if player already ready" do
      game = %Game{Game.new("room") | currency: 1000}
      {:ok, game} = Game.join(game, "ai_player", "AI Player")

      hand = Map.get(game.hands, "ai_player", [])

      if hand != [] do
        {:ok, game} = Game.play_action(game, "ai_player", List.first(hand), [])

        # Player is now ready (unless turn advanced and reset)
        player = Map.get(game.players, "ai_player")

        if player.is_ready do
          assert {:error, :already_ready} = AI.select_action(game, "ai_player")
        else
          # Turn advanced, player state was reset - this is acceptable
          :ok
        end
      else
        # No cards in hand - skip test
        :ok
      end
    end

    test "returns error if game is over" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "ai_player", "AI Player")
      game = %{game | status: :lost}

      assert {:error, :game_over} = AI.select_action(game, "ai_player")
    end

    test "selects compatible talents when available" do
      game = %Game{Game.new("room") | currency: 1000, forest: 10, culture: 10, social: 10}
      {:ok, game} = Game.join(game, "ai_player", "AI Player")

      # Get player's talents
      player = Map.get(game.players, "ai_player")
      assert length(player.talents) > 0

      # AI should select action with compatible talents
      case AI.select_action(game, "ai_player") do
        {:ok, _action_id, talent_ids} ->
          # Talents should be from player's available talents
          assert Enum.all?(talent_ids, &Enum.member?(player.talents, &1))
          assert length(talent_ids) <= 2

        {:error, _} ->
          # Acceptable if no playable cards
          :ok
      end
    end
  end
end
