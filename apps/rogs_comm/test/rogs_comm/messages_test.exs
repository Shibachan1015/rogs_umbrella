defmodule RogsComm.MessagesTest do
  use RogsComm.DataCase, async: true

  alias Ecto.Changeset
  alias RogsComm.Messages
  alias RogsComm.Messages.Message
  alias RogsComm.Repo
  alias RogsComm.Rooms

  import RogsComm.MessagesFixtures
  import RogsComm.RoomsFixtures

  describe "list_messages/2" do
    test "returns messages ordered oldest first" do
      room = room_fixture()
      older = message_fixture(%{room: room, content: "older"})
      newer = message_fixture(%{room: room, content: "newer"})

      older
      |> Changeset.change(inserted_at: DateTime.add(older.inserted_at, -60))
      |> Repo.update!()

      newer
      |> Changeset.change(inserted_at: DateTime.add(newer.inserted_at, 60))
      |> Repo.update!()

      assert [%Message{id: id1}, %Message{id: id2}] = Messages.list_messages(room.id)
      assert id1 == older.id
      assert id2 == newer.id
    end

    test "limits result size" do
      room = room_fixture()
      older = message_fixture(%{room: room})
      newer = message_fixture(%{room: room})

      older
      |> Changeset.change(inserted_at: DateTime.add(older.inserted_at, -60))
      |> Repo.update!()

      newer
      |> Changeset.change(inserted_at: DateTime.add(newer.inserted_at, 60))
      |> Repo.update!()

      assert [%Message{id: id}] = Messages.list_messages(room.id, limit: 1)
      assert id == newer.id
    end
  end

  describe "get_message!/1" do
    test "returns the message" do
      message = message_fixture()
      assert %Message{id: id} = Messages.get_message!(message.id)
      assert id == message.id
    end
  end

  describe "create_message/1" do
    test "with valid data creates message" do
      room = room_fixture()

      valid_attrs = %{
        content: "hello",
        user_id: Ecto.UUID.generate(),
        user_email: "user@example.com",
        room_id: room.id
      }

      assert {:ok, %Message{} = message} = Messages.create_message(valid_attrs)
      assert message.content == "hello"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Messages.create_message(%{})
    end
  end

  describe "update_message/2" do
    test "updates content" do
      message = message_fixture()
      assert {:ok, %Message{} = updated} = Messages.update_message(message, %{content: "updated"})
      assert updated.content == "updated"
    end
  end

  describe "delete_message/1" do
    test "deletes record" do
      message = message_fixture()
      assert {:ok, %Message{}} = Messages.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Messages.get_message!(message.id) end
    end
  end

  describe "change_message/2" do
    test "returns changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Messages.change_message(message)
    end
  end

  describe "integrity rules" do
    test "cascades delete when room removed" do
      room = room_fixture()
      message = message_fixture(%{room: room})

      {:ok, _} = Rooms.delete_room(room)

      assert_raise Ecto.NoResultsError, fn -> Messages.get_message!(message.id) end
    end

    test "validates content length" do
      room = room_fixture()

      long_attrs = %{
        content: String.duplicate("あ", 6000),
        user_id: Ecto.UUID.generate(),
        user_email: "user@example.com",
        room_id: room.id
      }

      assert {:error, changeset} = Messages.create_message(long_attrs)
      assert "should be at most 5000 character(s)" in errors_on(changeset).content
    end
  end

  describe "list_messages_before/3" do
    test "returns messages older than the given message_id" do
      room = room_fixture()
      older = message_fixture(%{room: room, content: "oldest"})
      middle = message_fixture(%{room: room, content: "middle"})
      newer = message_fixture(%{room: room, content: "newest"})

      older
      |> Changeset.change(inserted_at: DateTime.add(older.inserted_at, -120))
      |> Repo.update!()

      middle
      |> Changeset.change(inserted_at: DateTime.add(middle.inserted_at, -60))
      |> Repo.update!()

      newer
      |> Changeset.change(inserted_at: DateTime.add(newer.inserted_at, 60))
      |> Repo.update!()

      # Get messages before 'newer'
      older_messages = Messages.list_messages_before(room.id, newer.id)
      assert length(older_messages) == 2
      assert Enum.any?(older_messages, &(&1.id == older.id))
      assert Enum.any?(older_messages, &(&1.id == middle.id))
      refute Enum.any?(older_messages, &(&1.id == newer.id))
    end

    test "respects limit option" do
      room = room_fixture()
      base_message = message_fixture(%{room: room, content: "base"})

      # Create multiple older messages
      for i <- 1..5 do
        message_fixture(%{room: room, content: "older #{i}"})
        |> Changeset.change(inserted_at: DateTime.add(base_message.inserted_at, -i * 10))
        |> Repo.update!()
      end

      older_messages = Messages.list_messages_before(room.id, base_message.id, limit: 3)
      assert length(older_messages) == 3
    end

    test "returns empty list when message_id not found" do
      room = room_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert Messages.list_messages_before(room.id, non_existent_id) == []
    end

    test "returns empty list when message belongs to different room" do
      room1 = room_fixture()
      room2 = room_fixture()
      message_in_room2 = message_fixture(%{room: room2})

      assert Messages.list_messages_before(room1.id, message_in_room2.id) == []
    end

    test "excludes deleted messages by default" do
      room = room_fixture()
      older = message_fixture(%{room: room, content: "older"})
      deleted = message_fixture(%{room: room, content: "deleted"})
      newer = message_fixture(%{room: room, content: "newer"})

      older
      |> Changeset.change(inserted_at: DateTime.add(older.inserted_at, -120))
      |> Repo.update!()

      deleted
      |> Changeset.change(inserted_at: DateTime.add(deleted.inserted_at, -60), is_deleted: true)
      |> Repo.update!()

      newer
      |> Changeset.change(inserted_at: DateTime.add(newer.inserted_at, 60))
      |> Repo.update!()

      older_messages = Messages.list_messages_before(room.id, newer.id)
      assert length(older_messages) == 1
      assert hd(older_messages).id == older.id
      refute Enum.any?(older_messages, &(&1.id == deleted.id))
    end
  end

  describe "search_messages/3" do
    test "returns messages matching search query" do
      room = room_fixture()
      matching1 = message_fixture(%{room: room, content: "Hello world"})
      matching2 = message_fixture(%{room: room, content: "Hello there"})
      non_matching = message_fixture(%{room: room, content: "Goodbye"})

      results = Messages.search_messages(room.id, "Hello")
      assert length(results) == 2
      assert Enum.any?(results, &(&1.id == matching1.id))
      assert Enum.any?(results, &(&1.id == matching2.id))
      refute Enum.any?(results, &(&1.id == non_matching.id))
    end

    test "search is case insensitive" do
      room = room_fixture()
      message1 = message_fixture(%{room: room, content: "Hello World"})
      message2 = message_fixture(%{room: room, content: "hello world"})
      message3 = message_fixture(%{room: room, content: "HELLO WORLD"})

      results = Messages.search_messages(room.id, "hello")
      assert length(results) == 3
      assert Enum.any?(results, &(&1.id == message1.id))
      assert Enum.any?(results, &(&1.id == message2.id))
      assert Enum.any?(results, &(&1.id == message3.id))
    end

    test "search supports partial matching" do
      room = room_fixture()
      message1 = message_fixture(%{room: room, content: "This is a test message"})
      message2 = message_fixture(%{room: room, content: "Another test here"})
      non_matching = message_fixture(%{room: room, content: "No match"})

      results = Messages.search_messages(room.id, "test")
      assert length(results) == 2
      assert Enum.any?(results, &(&1.id == message1.id))
      assert Enum.any?(results, &(&1.id == message2.id))
      refute Enum.any?(results, &(&1.id == non_matching.id))
    end

    test "respects limit option" do
      room = room_fixture()

      # Create multiple matching messages
      for i <- 1..5 do
        message_fixture(%{room: room, content: "Hello #{i}"})
      end

      results = Messages.search_messages(room.id, "Hello", limit: 3)
      assert length(results) == 3
    end

    test "returns empty list when no matches found" do
      room = room_fixture()
      message_fixture(%{room: room, content: "Hello"})

      assert Messages.search_messages(room.id, "Goodbye") == []
    end

    test "excludes deleted messages by default" do
      room = room_fixture()
      matching = message_fixture(%{room: room, content: "Hello world"})
      deleted = message_fixture(%{room: room, content: "Hello deleted"})

      deleted
      |> Changeset.change(is_deleted: true)
      |> Repo.update!()

      results = Messages.search_messages(room.id, "Hello")
      assert length(results) == 1
      assert hd(results).id == matching.id
      refute Enum.any?(results, &(&1.id == deleted.id))
    end

    test "includes deleted messages when include_deleted is true" do
      room = room_fixture()
      matching = message_fixture(%{room: room, content: "Hello world"})
      deleted = message_fixture(%{room: room, content: "Hello deleted"})

      deleted
      |> Changeset.change(is_deleted: true)
      |> Repo.update!()

      results = Messages.search_messages(room.id, "Hello", include_deleted: true)
      assert length(results) == 2
      assert Enum.any?(results, &(&1.id == matching.id))
      assert Enum.any?(results, &(&1.id == deleted.id))
    end

    test "only searches messages in the specified room" do
      room1 = room_fixture()
      room2 = room_fixture()
      message1 = message_fixture(%{room: room1, content: "Hello in room1"})
      message2 = message_fixture(%{room: room2, content: "Hello in room2"})

      results = Messages.search_messages(room1.id, "Hello")
      assert length(results) == 1
      assert hd(results).id == message1.id
      refute Enum.any?(results, &(&1.id == message2.id))
    end

    test "returns messages in chronological order (oldest first)" do
      room = room_fixture()
      older = message_fixture(%{room: room, content: "Hello older"})
      newer = message_fixture(%{room: room, content: "Hello newer"})

      older
      |> Changeset.change(inserted_at: DateTime.add(older.inserted_at, -60))
      |> Repo.update!()

      newer
      |> Changeset.change(inserted_at: DateTime.add(newer.inserted_at, 60))
      |> Repo.update!()

      results = Messages.search_messages(room.id, "Hello")
      assert length(results) == 2
      assert hd(results).id == older.id
      assert List.last(results).id == newer.id
    end
  end
end
