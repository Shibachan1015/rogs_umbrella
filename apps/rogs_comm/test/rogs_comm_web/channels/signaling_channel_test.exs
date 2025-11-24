defmodule RogsCommWeb.SignalingChannelTest do
  use RogsCommWeb.ChannelCase, async: true

  alias RogsComm.Signaling

  import RogsComm.RoomsFixtures

  setup do
    room = room_fixture()
    {:ok, %{room: room}}
  end

  test "joins existing room", %{room: room} do
    {:ok, _, socket} =
      socket(RogsCommWeb.UserSocket)
      |> subscribe_and_join(RogsCommWeb.SignalingChannel, "signal:#{room.id}")

    assert socket.assigns.room_id == room.id
  end

  test "rejects missing room" do
    assert {:error, %{reason: "room not found"}} =
             socket(RogsCommWeb.UserSocket)
             |> subscribe_and_join(RogsCommWeb.SignalingChannel, "signal:missing")
  end

  test "broadcasts offer event", %{room: room} do
    {:ok, _, socket} =
      socket(RogsCommWeb.UserSocket, "user_id", %{})
      |> subscribe_and_join(RogsCommWeb.SignalingChannel, "signal:#{room.id}")

    room_id = room.id

    push(socket, "offer", %{"sdp" => "dummy"})
    assert_broadcast "offer", %{"sdp" => "dummy", "room_id" => ^room_id}
  end

  test "saves signaling session when offer event is sent", %{room: room} do
    user_id = Ecto.UUID.generate()

    {:ok, _, socket} =
      socket(RogsCommWeb.UserSocket, user_id, %{})
      |> subscribe_and_join(RogsCommWeb.SignalingChannel, "signal:#{room.id}")

    push(socket, "offer", %{"sdp" => "test-offer-sdp"})

    # Wait for async database insert
    Process.sleep(100)

    sessions = Signaling.list_sessions(room.id)
    assert length(sessions) == 1

    session = hd(sessions)
    assert session.room_id == room.id
    assert session.from_user_id == user_id
    assert session.event_type == "offer"
    assert session.payload["sdp"] == "test-offer-sdp"
  end

  test "saves signaling session with to_user_id when specified", %{room: room} do
    from_user_id = Ecto.UUID.generate()
    to_user_id = Ecto.UUID.generate()

    {:ok, _, socket} =
      socket(RogsCommWeb.UserSocket, from_user_id, %{})
      |> subscribe_and_join(RogsCommWeb.SignalingChannel, "signal:#{room.id}")

    push(socket, "answer", %{"sdp" => "test-answer-sdp", "to" => to_user_id})

    # Wait for async database insert
    Process.sleep(100)

    sessions = Signaling.list_sessions(room.id)
    assert length(sessions) == 1

    session = hd(sessions)
    assert session.from_user_id == from_user_id
    assert session.to_user_id == to_user_id
    assert session.event_type == "answer"
  end
end
