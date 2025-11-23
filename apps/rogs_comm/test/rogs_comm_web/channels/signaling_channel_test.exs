defmodule RogsCommWeb.SignalingChannelTest do
  use RogsCommWeb.ChannelCase, async: true

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
end
