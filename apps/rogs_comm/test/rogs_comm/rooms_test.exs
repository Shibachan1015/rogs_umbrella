defmodule RogsComm.RoomsTest do
  use RogsComm.DataCase, async: true

  alias RogsComm.Rooms
  alias RogsComm.Rooms.Room

  import RogsComm.RoomsFixtures

  describe "list_rooms/1" do
    test "returns all rooms ordered newest first" do
      older = room_fixture(%{name: "Older"})
      newer = room_fixture(%{name: "Newer"})

      older
      |> change(inserted_at: DateTime.add(older.inserted_at, -60))
      |> Repo.update!()

      ids = Rooms.list_rooms() |> Enum.map(& &1.id)
      assert ids == [newer.id, older.id]
    end

    test "can exclude private rooms" do
      public_room = room_fixture(%{is_private: false})
      _private_room = room_fixture(%{is_private: true})

      ids =
        Rooms.list_rooms(include_private: false)
        |> Enum.map(& &1.id)

      assert ids == [public_room.id]
    end
  end

  describe "get/fetch helpers" do
    test "get_room!/1 returns the room" do
      room = room_fixture()
      assert %Room{id: room_id} = Rooms.get_room!(room.id)
      assert room_id == room.id
    end

    test "fetch_room/1 returns nil when missing" do
      assert Rooms.fetch_room(Ecto.UUID.generate()) == nil
    end

    test "get_room_by_slug!/1 returns the room" do
      room = room_fixture(%{slug: "custom-slug"})
      assert %Room{id: room_id} = Rooms.get_room_by_slug!("custom-slug")
      assert room_id == room.id
    end

    test "fetch_room_by_slug/1 returns nil when not found" do
      assert Rooms.fetch_room_by_slug("missing") == nil
    end
  end

  describe "create_room/1" do
    test "succeeds with valid data" do
      valid_attrs = %{name: "Forest Watch", slug: "forest-watch", max_participants: 6}

      assert {:ok, %Room{} = room} = Rooms.create_room(valid_attrs)
      assert room.name == "Forest Watch"
      assert room.slug == "forest-watch"
      assert room.max_participants == 6
    end

    test "auto-generates slug from name" do
      assert {:ok, %Room{} = room} = Rooms.create_room(%{name: "Sun Rise"})
      assert room.slug == "sun-rise"
    end

    test "fails when required fields are missing" do
      assert {:error, changeset} = Rooms.create_room(%{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_room/2" do
    test "persists changes" do
      room = room_fixture()
      assert {:ok, %Room{} = updated} = Rooms.update_room(room, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "returns error changeset for invalid updates" do
      room = room_fixture()
      assert {:error, changeset} = Rooms.update_room(room, %{slug: "INVALID SLUG"})
      assert %{slug: [_ | _]} = errors_on(changeset)
    end
  end

  describe "delete_room/1" do
    test "removes the record" do
      room = room_fixture()
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end
  end

  describe "change_room/2" do
    test "returns changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Rooms.change_room(room)
    end
  end
end
