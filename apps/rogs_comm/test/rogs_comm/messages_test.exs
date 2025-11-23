defmodule RogsComm.MessagesTest do
  use RogsComm.DataCase, async: true

  alias Ecto.Changeset
  alias RogsComm.Messages
  alias RogsComm.Messages.Message
  alias RogsComm.Repo

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
end
