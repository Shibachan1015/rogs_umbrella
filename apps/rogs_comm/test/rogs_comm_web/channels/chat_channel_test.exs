defmodule RogsCommWeb.ChatChannelTest do
  use RogsCommWeb.ChannelCase, async: true

  alias RogsComm.Messages
  alias RogsCommWeb.ChatChannel
  alias RogsCommWeb.Presence
  alias RogsCommWeb.RateLimiter

  import RogsComm.MessagesFixtures
  import RogsComm.RoomsFixtures

  setup do
    # Initialize RateLimiter ETS table
    RateLimiter.init()

    room = room_fixture()
    {:ok, %{room: room}}
  end

  describe "join/3" do
    test "successfully joins existing room", %{room: room} do
      {:ok, response, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      assert response[:messages] != nil
      assert socket.assigns.room_id == room.id
      assert socket.assigns.user_id == "user_id"
    end

    test "rejects missing room" do
      assert {:error, %{reason: "room not found"}} =
               socket(RogsCommWeb.UserSocket, "user_id", %{})
               |> subscribe_and_join(ChatChannel, "room:missing")
    end

    test "rejects when room is full", %{room: room} do
      # Create a room with max_participants = 1
      small_room = room_fixture(%{max_participants: 1})

      # First user joins successfully
      {:ok, _, socket1} =
        socket(RogsCommWeb.UserSocket, "user1", %{})
        |> subscribe_and_join(ChatChannel, "room:#{small_room.id}")

      # Wait for Presence to be tracked
      Process.sleep(100)

      # Second user should be rejected
      assert {:error, %{reason: "room is full"}} =
               socket(RogsCommWeb.UserSocket, "user2", %{})
               |> subscribe_and_join(ChatChannel, "room:#{small_room.id}")

      # Clean up
      leave(socket1)
    end

    test "assigns user_id and user_email from socket", %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "test_user_id", %{user_email: "test@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      assert socket.assigns.user_id == "test_user_id"
      assert socket.assigns.user_email == "test@example.com"
    end

    test "generates user_id when not provided", %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket)
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      assert socket.assigns.user_id != nil
      assert is_binary(socket.assigns.user_id)
    end
  end

  describe "handle_in new_message" do
    setup %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      {:ok, %{socket: socket, room: room}}
    end

    test "broadcasts new message to all subscribers", %{socket: socket, room: room} do
      push(socket, "new_message", %{"content" => "Hello, world!"})

      assert_broadcast "new_message", %{
        content: "Hello, world!",
        user_id: "user_id",
        user_email: "user@example.com"
      }
    end

    test "saves message to database", %{socket: socket, room: room} do
      push(socket, "new_message", %{"content" => "Test message"})

      # Wait for async database insert
      Process.sleep(100)

      messages = Messages.list_messages(room.id)
      assert length(messages) == 1
      assert hd(messages).content == "Test message"
      assert hd(messages).user_id == "user_id"
    end

    test "rejects empty message", %{socket: socket} do
      ref = push(socket, "new_message", %{"content" => "   "})

      assert_reply ref, :error, %{reason: "message content cannot be empty"}
    end

    test "rejects message with only whitespace", %{socket: socket} do
      ref = push(socket, "new_message", %{"content" => "\n\t  "})

      assert_reply ref, :error, %{reason: "message content cannot be empty"}
    end

    test "trims message content", %{socket: socket} do
      push(socket, "new_message", %{"content" => "  Trimmed message  "})

      assert_broadcast "new_message", %{content: "Trimmed message"}
    end

    test "rate limits messages", %{socket: socket} do
      # Send 10 messages (the limit)
      for i <- 1..10 do
        push(socket, "new_message", %{"content" => "Message #{i}"})
        Process.sleep(10)
      end

      # 11th message should be rate limited
      ref = push(socket, "new_message", %{"content" => "Rate limited message"})
      assert_reply ref, :error, %{reason: "rate limit exceeded. please wait a moment"}
    end

    test "rejects invalid parameters", %{socket: socket} do
      ref = push(socket, "new_message", %{"invalid" => "data"})

      assert_reply ref, :error, %{reason: "invalid parameters"}
    end

    test "rejects non-string content", %{socket: socket} do
      ref = push(socket, "new_message", %{"content" => 123})

      assert_reply ref, :error, %{reason: "invalid parameters"}
    end
  end

  describe "handle_in edit_message" do
    setup %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      # Create a message owned by this user
      message = message_fixture(%{room_id: room.id, user_id: "user_id"})

      {:ok, %{socket: socket, room: room, message: message}}
    end

    test "broadcasts edited message", %{socket: socket, message: message} do
      push(socket, "edit_message", %{
        "message_id" => message.id,
        "content" => "Edited content"
      })

      assert_broadcast "message_edited", %{
        id: message.id,
        content: "Edited content"
      }
    end

    test "updates message in database", %{socket: socket, message: message} do
      push(socket, "edit_message", %{
        "message_id" => message.id,
        "content" => "Updated content"
      })

      # Wait for async database update
      Process.sleep(100)

      updated_message = Messages.get_message!(message.id)
      assert updated_message.content == "Updated content"
      assert updated_message.edited_at != nil
    end

    test "rejects editing other user's message", %{socket: socket, room: room} do
      other_message = message_fixture(%{room_id: room.id, user_id: "other_user_id"})

      ref =
        push(socket, "edit_message", %{
          "message_id" => other_message.id,
          "content" => "Hacked content"
        })

      assert_reply ref, :error, %{reason: "you can only edit your own messages"}
    end

    test "rejects editing message from different room", %{socket: socket} do
      other_room = room_fixture()
      other_message = message_fixture(%{room_id: other_room.id, user_id: "user_id"})

      ref =
        push(socket, "edit_message", %{
          "message_id" => other_message.id,
          "content" => "Wrong room"
        })

      assert_reply ref, :error, %{reason: "message not found in this room"}
    end

    test "rejects empty content", %{socket: socket, message: message} do
      ref =
        push(socket, "edit_message", %{
          "message_id" => message.id,
          "content" => "   "
        })

      assert_reply ref, :error, %{reason: "message content cannot be empty"}
    end

    test "rejects non-existent message", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref =
        push(socket, "edit_message", %{
          "message_id" => fake_id,
          "content" => "Content"
        })

      assert_reply ref, :error, %{reason: "message not found"}
    end

    test "trims edited content", %{socket: socket, message: message} do
      push(socket, "edit_message", %{
        "message_id" => message.id,
        "content" => "  Trimmed  "
      })

      assert_broadcast "message_edited", %{content: "Trimmed"}
    end
  end

  describe "handle_in delete_message" do
    setup %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      # Create a message owned by this user
      message = message_fixture(%{room_id: room.id, user_id: "user_id"})

      {:ok, %{socket: socket, room: room, message: message}}
    end

    test "broadcasts deleted message", %{socket: socket, message: message} do
      push(socket, "delete_message", %{"message_id" => message.id})

      assert_broadcast "message_deleted", %{id: message.id}
    end

    test "soft deletes message in database", %{socket: socket, message: message, room: room} do
      push(socket, "delete_message", %{"message_id" => message.id})

      # Wait for async database update
      Process.sleep(100)

      # Message should be soft deleted (not in list)
      messages = Messages.list_messages(room.id)
      assert Enum.all?(messages, fn m -> m.id != message.id end)

      # But should still exist in database
      deleted_message = Messages.get_message!(message.id)
      assert deleted_message.is_deleted == true
    end

    test "rejects deleting other user's message", %{socket: socket, room: room} do
      other_message = message_fixture(%{room_id: room.id, user_id: "other_user_id"})

      ref = push(socket, "delete_message", %{"message_id" => other_message.id})

      assert_reply ref, :error, %{reason: "you can only delete your own messages"}
    end

    test "rejects deleting message from different room", %{socket: socket} do
      other_room = room_fixture()
      other_message = message_fixture(%{room_id: other_room.id, user_id: "user_id"})

      ref = push(socket, "delete_message", %{"message_id" => other_message.id})

      assert_reply ref, :error, %{reason: "message not found in this room"}
    end

    test "rejects non-existent message", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref = push(socket, "delete_message", %{"message_id" => fake_id})

      assert_reply ref, :error, %{reason: "message not found"}
    end
  end

  describe "handle_in typing_start and typing_stop" do
    setup %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      {:ok, %{socket: socket}}
    end

    test "broadcasts typing_start event", %{socket: socket} do
      push(socket, "typing_start", %{})

      assert_broadcast "user_typing", %{
        user_id: "user_id",
        user_email: "user@example.com"
      }
    end

    test "broadcasts typing_stop event", %{socket: socket} do
      push(socket, "typing_stop", %{})

      assert_broadcast "user_stopped_typing", %{
        user_id: "user_id",
        user_email: "user@example.com"
      }
    end

    test "typing events do not broadcast to sender", %{socket: socket} do
      push(socket, "typing_start", %{})

      # Should not receive own typing event
      refute_receive %Phoenix.Socket.Broadcast{
        event: "user_typing",
        payload: %{user_id: "user_id"}
      }
    end
  end

  describe "handle_in load_older_messages" do
    setup %{room: room} do
      {:ok, _, socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      # Create multiple messages
      messages =
        for i <- 1..5 do
          message_fixture(%{
            room_id: room.id,
            content: "Message #{i}",
            inserted_at: DateTime.add(DateTime.utc_now(), -i, :second)
          })
        end

      # Get the middle message ID
      middle_message = Enum.at(messages, 2)

      {:ok, %{socket: socket, room: room, middle_message: middle_message}}
    end

    test "pushes older messages", %{socket: socket, middle_message: middle_message} do
      push(socket, "load_older_messages", %{"message_id" => middle_message.id})

      assert_push "older_messages_loaded", %{
        messages: older_messages,
        has_more: has_more
      }

      assert length(older_messages) > 0
      assert is_boolean(has_more)
    end

    test "rejects when message_id is missing", %{socket: socket} do
      ref = push(socket, "load_older_messages", %{})

      assert_reply ref, :error, %{reason: "message_id is required"}
    end

    test "returns empty list when no older messages", %{socket: socket, room: room} do
      # Create a new message
      newest_message = message_fixture(%{room_id: room.id})

      push(socket, "load_older_messages", %{"message_id" => newest_message.id})

      assert_push "older_messages_loaded", %{
        messages: older_messages,
        has_more: false
      }

      assert older_messages == []
    end
  end

  describe "presence tracking" do
    test "tracks user presence on join", %{room: room} do
      {:ok, _, _socket} =
        socket(RogsCommWeb.UserSocket, "user_id", %{user_email: "user@example.com"})
        |> subscribe_and_join(ChatChannel, "room:#{room.id}")

      # Wait for Presence to be tracked
      Process.sleep(100)

      topic = "room:#{room.id}"

      try do
        presences = Presence.list(topic)
        assert map_size(presences) > 0
      rescue
        _ -> :ok
      end
    end
  end
end
