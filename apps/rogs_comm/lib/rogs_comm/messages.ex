defmodule RogsComm.Messages do
  @moduledoc """
  Provides the data access API for chat messages, including
  listing, creation, and lifecycle helpers.
  """

  import Ecto.Query, warn: false

  alias RogsComm.Repo
  alias RogsComm.Messages.Message

  @doc """
  Lists messages for a room, returning them in chronological order.
  """
  def list_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Gets a single message by ID.
  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a message.
  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end
end
