defmodule Shinkanki.GameServerTest do
  use ExUnit.Case, async: true

  setup do
    # Ensure the PubSub is started (it is part of the supervision tree, but good to be aware)
    # We will use a unique room_id for each test to avoid collision
    room_id = "room_#{System.unique_integer([:positive])}"
    {:ok, room_id: room_id}
  end

  # Helper to start a game session and start the game with a player
  defp start_playing_game(room_id) do
    {:ok, _pid} = Shinkanki.start_game_session(room_id)
    {:ok, _} = Shinkanki.join_player(room_id, "test_player", "Test Player")
    {:ok, _} = Shinkanki.start_game(room_id)
    :ok
  end

  describe "integration flow" do
    test "starts game, updates stats, and notifies subscribers", %{room_id: room_id} do
      # 1. Subscribe to game updates
      Shinkanki.subscribe_game(room_id)

      # 2. Start the game session
      assert {:ok, _pid} = Shinkanki.start_game_session(room_id)

      # 3. Join a player and start the game
      {:ok, _} = Shinkanki.join_player(room_id, "test_player", "Test Player")
      {:ok, _} = Shinkanki.start_game(room_id)

      # 4. Verify initial state
      initial_state = Shinkanki.get_current_state(room_id)
      assert initial_state.room_id == room_id
      assert initial_state.turn == 1
      assert initial_state.status == :playing

      # Note: start_game draws and applies an event card which may modify forest
      initial_forest = initial_state.forest

      # 5. Update stats manually
      updated_state = Shinkanki.update_stats(room_id, forest: 2)
      # Initial forest + 2 (new 0-10 scale, clamped to 0-10)
      expected_forest = min(initial_forest + 2, 10)
      assert updated_state.forest == expected_forest

      # 6. Verify PubSub notification for update
      assert_receive {:game_state_updated, ^updated_state}

      # 7. Advance turn
      turn_state = Shinkanki.next_turn(room_id)
      assert turn_state.turn == 2
      # Currency may be affected by event cards and demurrage (new scale: initial 10)
      assert turn_state.currency <= 10

      # 8. Verify PubSub notification for turn
      assert_receive {:game_state_updated, ^turn_state}
    end

    test "returns nil for non-existent game" do
      assert Shinkanki.get_current_state("non_existent_room") == nil
    end

    test "handles win condition flow", %{room_id: room_id} do
      start_playing_game(room_id)

      # Force game to turn 20 with high stats (via multiple manual updates or just one if we exposed set_state,
      # but here we use update_stats logic which adds values.
      # To simulate turn 20 quickly, we might need a backdoor or just call next_turn 19 times.
      # For this integration test, let's just verify standard flow.
      # But to be thorough, let's loop.)

      # Advance to turn 20, checking if game ends early
      final_state =
        Enum.reduce_while(1..20, nil, fn _turn, _acc ->
          state = Shinkanki.next_turn(room_id)

          if state.status in [:won, :lost] do
            {:halt, state}
          else
            {:cont, state}
          end
        end)

      # Game should end after 20 turns (at turn 21) or earlier if a stat hits 0
      assert final_state.status in [:won, :lost]
      assert final_state.turn >= 2
    end
  end
end
