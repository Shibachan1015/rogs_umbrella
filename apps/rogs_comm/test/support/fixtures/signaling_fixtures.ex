defmodule RogsComm.SignalingFixtures do
  @moduledoc """
  Fixtures for the Signaling context.
  """

  alias RogsComm.Signaling
  alias RogsComm.RoomsFixtures

  def signaling_session_attrs(attrs \\ %{}) do
    room = RoomsFixtures.room_fixture()

    Enum.into(attrs, %{
      room_id: room.id,
      from_user_id: Ecto.UUID.generate(),
      to_user_id: Ecto.UUID.generate(),
      event_type: "offer",
      payload: %{"sdp" => "test-sdp", "from" => "user1", "to" => "user2"},
      created_at: DateTime.utc_now()
    })
  end

  def signaling_session_fixture(attrs \\ %{}) do
    attrs
    |> signaling_session_attrs()
    |> Signaling.create_session()
    |> case do
      {:ok, session} -> session
      {:error, changeset} -> raise "signaling_session_fixture failed: #{inspect(changeset.errors)}"
    end
  end
end
