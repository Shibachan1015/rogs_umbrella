defmodule RogsComm.Signaling do
  @moduledoc """
  The Signaling context for tracking WebRTC signaling sessions.
  """

  import Ecto.Query, warn: false
  alias RogsComm.Repo

  alias RogsComm.Signaling.SignalingSession

  @doc """
  Creates a signaling session log entry.
  """
  def create_session(attrs \\ %{}) do
    attrs_with_timestamp =
      attrs
      |> Map.put_new(:created_at, DateTime.utc_now())

    %SignalingSession{}
    |> SignalingSession.changeset(attrs_with_timestamp)
    |> Repo.insert()
  end

  @doc """
  Lists signaling sessions for a room.
  """
  def list_sessions(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    SignalingSession
    |> where([s], s.room_id == ^room_id)
    |> order_by([s], desc: s.created_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists signaling sessions between two users.
  """
  def list_sessions_between(room_id, from_user_id, to_user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    SignalingSession
    |> where([s], s.room_id == ^room_id)
    |> where([s], s.from_user_id == ^from_user_id and s.to_user_id == ^to_user_id)
    |> or_where([s], s.from_user_id == ^to_user_id and s.to_user_id == ^from_user_id)
    |> order_by([s], desc: s.created_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
