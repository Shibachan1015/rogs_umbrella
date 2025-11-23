defmodule Shinkanki.GameServerTest do
  use ExUnit.Case, async: true

  setup do
    # Ensure the PubSub is started (it is part of the supervision tree, but good to be aware)
    # We will use a unique room_id for each test to avoid collision
    room_id = "room_#{System.unique_integer([:positive])}"
    {:ok, room_id: room_id}
  end

  describe "integration flow" do
    test "starts game, updates stats, and notifies subscribers", %{room_id: room_id} do
      # 1. Subscribe to game updates
      Shinkanki.subscribe_game(room_id)

      # 2. Start the game
      assert {:ok, _pid} = Shinkanki.start_game_session(room_id)

      # 3. Verify initial state
      initial_state = Shinkanki.get_current_state(room_id)
      assert initial_state.room_id == room_id
      assert initial_state.turn == 1

      # 4. Update stats manually
      updated_state = Shinkanki.update_stats(room_id, forest: 10)
      assert updated_state.forest == 60 # Initial 50 + 10

      # 5. Verify PubSub notification for update
      assert_receive {:game_state_updated, ^updated_state}

      # 6. Advance turn
      turn_state = Shinkanki.next_turn(room_id)
      assert turn_state.turn == 2
      assert turn_state.currency == 90 # 100 * 0.9

      # 7. Verify PubSub notification for turn
      assert_receive {:game_state_updated, ^turn_state}
    end

    test "returns nil for non-existent game" do
      assert Shinkanki.get_current_state("non_existent_room") == nil
    end

    test "handles win condition flow", %{room_id: room_id} do
      Shinkanki.start_game_session(room_id)

      # Force game to turn 20 with high stats (via multiple manual updates or just one if we exposed set_state,
      # but here we use update_stats logic which adds values.
      # To simulate turn 20 quickly, we might need a backdoor or just call next_turn 19 times.
      # For this integration test, let's just verify standard flow.
      # But to be thorough, let's loop.)

      # Advance to turn 20
      Enum.each(1..19, fn _ -> Shinkanki.next_turn(room_id) end)

      state_20 = Shinkanki.get_current_state(room_id)
      assert state_20.turn == 20

      # Advance to end game
      final_state = Shinkanki.next_turn(room_id)
      assert final_state.turn == 21

      # Since we didn't change stats, Life Index is 150 (initial) which is >= 40.
      # So it should be a win.
      assert final_state.status == :won
    end
  end
end
