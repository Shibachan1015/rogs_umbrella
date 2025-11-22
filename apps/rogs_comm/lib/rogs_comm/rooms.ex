defmodule RogsComm.Rooms do
  @moduledoc """
  Provides the data access API for chat rooms, including creation,
  retrieval, and lifecycle helpers.
  """

  import Ecto.Query, warn: false

  alias RogsComm.Repo
  alias RogsComm.Rooms.Room

  @doc """
  Lists rooms ordered by newest first.

  Set `include_private: false` to exclude private rooms.
  """
  def list_rooms(opts \\ []) do
    include_private? = Keyword.get(opts, :include_private, true)

    Room
    |> maybe_filter_private(include_private?)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_private(query, true), do: query

  defp maybe_filter_private(query, false) do
    from r in query, where: r.is_private == false
  end

  @doc """
  Gets a single room by ID.
  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Fetches a room by ID, returning `nil` when not found.
  """
  def fetch_room(id), do: Repo.get(Room, id)

  @doc """
  Gets a room by slug, raising when not found.
  """
  def get_room_by_slug!(slug) when is_binary(slug) do
    Repo.get_by!(Room, slug: slug)
  end

  @doc """
  Fetches a room by slug, returning `nil` when not found.
  """
  def fetch_room_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Room, slug: slug)
  end

  @doc """
  Creates a room.
  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.
  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end
end
