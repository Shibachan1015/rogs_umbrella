defmodule RogsComm.SignalingTest do
  use RogsComm.DataCase, async: true

  alias RogsComm.Signaling
  alias RogsComm.Signaling.SignalingSession
  alias RogsComm.Repo

  import RogsComm.SignalingFixtures
  import RogsComm.RoomsFixtures

  describe "create_session/1" do
    test "creates a signaling session with valid data" do
      room = room_fixture()
      from_user_id = Ecto.UUID.generate()
      to_user_id = Ecto.UUID.generate()

      attrs = %{
        room_id: room.id,
        from_user_id: from_user_id,
        to_user_id: to_user_id,
        event_type: "offer",
        payload: %{"sdp" => "test-sdp"},
        created_at: DateTime.utc_now()
      }

      assert {:ok, %SignalingSession{} = session} = Signaling.create_session(attrs)
      assert session.room_id == room.id
      assert session.from_user_id == from_user_id
      assert session.to_user_id == to_user_id
      assert session.event_type == "offer"
      assert session.payload == %{"sdp" => "test-sdp"}
    end

    test "auto-generates created_at if not provided" do
      room = room_fixture()

      attrs = %{
        room_id: room.id,
        from_user_id: Ecto.UUID.generate(),
        event_type: "answer",
        payload: %{"sdp" => "test-answer"}
      }

      assert {:ok, %SignalingSession{} = session} = Signaling.create_session(attrs)
      assert session.created_at != nil
    end

    test "fails with invalid event_type" do
      room = room_fixture()

      attrs = %{
        room_id: room.id,
        from_user_id: Ecto.UUID.generate(),
        event_type: "invalid-event",
        payload: %{"sdp" => "test"}
      }

      assert {:error, changeset} = Signaling.create_session(attrs)
      assert %{event_type: ["is invalid"]} = errors_on(changeset)
    end

    test "fails when required fields are missing" do
      assert {:error, changeset} = Signaling.create_session(%{})

      assert %{
               room_id: ["can't be blank"],
               from_user_id: ["can't be blank"],
               event_type: ["can't be blank"],
               payload: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "list_sessions/2" do
    test "returns sessions for a room ordered newest first" do
      room = room_fixture()
      older = signaling_session_fixture(%{room_id: room.id, event_type: "offer"})
      newer = signaling_session_fixture(%{room_id: room.id, event_type: "answer"})

      older
      |> Ecto.Changeset.change(created_at: DateTime.add(older.created_at, -60))
      |> Repo.update!()

      newer
      |> Ecto.Changeset.change(created_at: DateTime.add(newer.created_at, 60))
      |> Repo.update!()

      sessions = Signaling.list_sessions(room.id)
      assert length(sessions) == 2
      assert hd(sessions).id == newer.id
      assert List.last(sessions).id == older.id
    end

    test "respects limit option" do
      room = room_fixture()

      for i <- 1..5 do
        signaling_session_fixture(%{room_id: room.id, event_type: "offer"})
      end

      sessions = Signaling.list_sessions(room.id, limit: 3)
      assert length(sessions) == 3
    end

    test "returns empty list for non-existent room" do
      assert Signaling.list_sessions(Ecto.UUID.generate()) == []
    end
  end

  describe "list_sessions_between/4" do
    test "returns sessions between two users" do
      room = room_fixture()
      from_user_id = Ecto.UUID.generate()
      to_user_id = Ecto.UUID.generate()
      other_user_id = Ecto.UUID.generate()

      # Sessions between from_user and to_user
      session1 =
        signaling_session_fixture(%{
          room_id: room.id,
          from_user_id: from_user_id,
          to_user_id: to_user_id,
          event_type: "offer"
        })

      session2 =
        signaling_session_fixture(%{
          room_id: room.id,
          from_user_id: to_user_id,
          to_user_id: from_user_id,
          event_type: "answer"
        })

      # Session with other user (should not be included)
      signaling_session_fixture(%{
        room_id: room.id,
        from_user_id: from_user_id,
        to_user_id: other_user_id,
        event_type: "offer"
      })

      sessions = Signaling.list_sessions_between(room.id, from_user_id, to_user_id)
      assert length(sessions) == 2
      assert Enum.any?(sessions, &(&1.id == session1.id))
      assert Enum.any?(sessions, &(&1.id == session2.id))
    end

    test "respects limit option" do
      room = room_fixture()
      from_user_id = Ecto.UUID.generate()
      to_user_id = Ecto.UUID.generate()

      for _i <- 1..5 do
        signaling_session_fixture(%{
          room_id: room.id,
          from_user_id: from_user_id,
          to_user_id: to_user_id,
          event_type: "offer"
        })
      end

      sessions = Signaling.list_sessions_between(room.id, from_user_id, to_user_id, limit: 3)
      assert length(sessions) == 3
    end

    test "returns empty list when no sessions exist between users" do
      room = room_fixture()
      from_user_id = Ecto.UUID.generate()
      to_user_id = Ecto.UUID.generate()

      assert Signaling.list_sessions_between(room.id, from_user_id, to_user_id) == []
    end
  end
end
