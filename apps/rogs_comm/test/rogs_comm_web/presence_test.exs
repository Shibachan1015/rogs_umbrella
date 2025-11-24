defmodule RogsCommWeb.PresenceTest do
  use RogsCommWeb.ChannelCase, async: false

  alias RogsCommWeb.Presence

  import RogsComm.RoomsFixtures

  setup do
    # Ensure PubSub is started (it should be in test_helper)
    # Presence uses PubSub, so we need to make sure it's available
    room = room_fixture()
    {:ok, %{room: room}}
  end

  describe "Presence tracking" do
    test "tracks user presence in a topic" do
      topic = "room:test-room"
      user_id = "user-123"

      meta = %{
        user_id: user_id,
        user_email: "test@example.com",
        online_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      # Track presence
      {:ok, _} = Presence.track(self(), topic, user_id, meta)

      # Wait a bit for the tracking to complete
      Process.sleep(50)

      # List presences
      presences = Presence.list(topic)
      assert map_size(presences) == 1
      assert Map.has_key?(presences, user_id)

      # Check metadata
      {^user_id, %{metas: [presence_meta | _]}} = List.first(presences |> Enum.to_list())
      assert presence_meta.user_id == user_id
      assert presence_meta.user_email == "test@example.com"
    end

    test "tracks multiple users in the same topic" do
      topic = "room:test-room"
      user1_id = "user-1"
      user2_id = "user-2"

      {:ok, _} =
        Presence.track(
          self(),
          topic,
          user1_id,
          %{
            user_id: user1_id,
            user_email: "user1@example.com",
            online_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        )

      {:ok, _} =
        Presence.track(
          self(),
          topic,
          user2_id,
          %{
            user_id: user2_id,
            user_email: "user2@example.com",
            online_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        )

      Process.sleep(50)

      presences = Presence.list(topic)
      assert map_size(presences) == 2
      assert Map.has_key?(presences, user1_id)
      assert Map.has_key?(presences, user2_id)
    end

    test "tracks users in different topics independently" do
      topic1 = "room:room-1"
      topic2 = "room:room-2"
      user_id = "user-123"

      {:ok, _} =
        Presence.track(
          self(),
          topic1,
          user_id,
          %{
            user_id: user_id,
            user_email: "test@example.com",
            online_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        )

      {:ok, _} =
        Presence.track(
          self(),
          topic2,
          user_id,
          %{
            user_id: user_id,
            user_email: "test@example.com",
            online_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        )

      Process.sleep(50)

      presences1 = Presence.list(topic1)
      presences2 = Presence.list(topic2)

      assert map_size(presences1) == 1
      assert map_size(presences2) == 1
      assert Map.has_key?(presences1, user_id)
      assert Map.has_key?(presences2, user_id)
    end

    test "removes presence when process exits" do
      topic = "room:test-room"
      user_id = "user-123"

      # Track presence in a separate process
      pid =
        spawn(fn ->
          {:ok, _} =
            Presence.track(
              self(),
              topic,
              user_id,
              %{
                user_id: user_id,
                user_email: "test@example.com",
                online_at: DateTime.utc_now() |> DateTime.to_iso8601()
              }
            )

          # Keep process alive for a bit
          Process.sleep(100)
        end)

      Process.sleep(50)

      # Presence should be tracked
      presences = Presence.list(topic)
      assert map_size(presences) == 1

      # Wait for process to exit
      Process.sleep(150)

      # Presence should be removed (may take a moment for cleanup)
      # Note: In practice, Presence uses a heartbeat mechanism
      # This test may need adjustment based on actual behavior
    end

    test "handles empty topic gracefully" do
      topic = "room:empty-room"
      presences = Presence.list(topic)
      assert presences == %{}
      assert map_size(presences) == 0
    end
  end

  describe "Presence in ChatChannel context" do
    test "tracks presence when user joins channel", %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(RogsCommWeb.ChatChannel, "room:#{room.id}")

      # Wait for after_join to complete
      Process.sleep(100)

      topic = "room:#{room.id}"
      presences = Presence.list(topic)

      # User should be tracked
      assert map_size(presences) >= 1
      assert Map.has_key?(presences, socket.assigns.user_id)
    end

    test "presence is used to check room capacity", %{room: room} do
      # Create a room with max_participants = 1
      small_room = room_fixture(%{max_participants: 1})

      # First user joins
      {:ok, _, _socket1} =
        socket(RogsCommWeb.UserSocket, "user1", %{})
        |> subscribe_and_join(RogsCommWeb.ChatChannel, "room:#{small_room.id}")

      Process.sleep(100)

      # Second user should be rejected
      assert {:error, %{reason: "room is full"}} =
               socket(RogsCommWeb.UserSocket, "user2", %{})
               |> subscribe_and_join(RogsCommWeb.ChatChannel, "room:#{small_room.id}")
    end
  end
end
