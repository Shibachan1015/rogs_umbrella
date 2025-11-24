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
  Excludes deleted messages by default.
  """
  def list_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    include_deleted = Keyword.get(opts, :include_deleted, false)

    Message
    |> where([m], m.room_id == ^room_id)
    |> maybe_filter_deleted(include_deleted)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Lists messages before a specific message ID (for pagination).
  Returns messages older than the given message_id.
  """
  def list_messages_before(room_id, message_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    include_deleted = Keyword.get(opts, :include_deleted, false)

    # Get the message to find its inserted_at timestamp
    case Repo.get(Message, message_id) do
      nil ->
        []

      message when message.room_id == room_id ->
        Message
        |> where([m], m.room_id == ^room_id)
        |> where([m], m.inserted_at < ^message.inserted_at)
        |> maybe_filter_deleted(include_deleted)
        |> order_by([m], desc: m.inserted_at)
        |> limit(^limit)
        |> Repo.all()
        |> Enum.reverse()

      _ ->
        []
    end
  end

  defp maybe_filter_deleted(query, true), do: query

  defp maybe_filter_deleted(query, false) do
    where(query, [m], m.is_deleted == false)
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
  Deletes a message (hard delete).
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Soft deletes a message by marking it as deleted.
  """
  def soft_delete_message(%Message{} = message) do
    message
    |> Ecto.Changeset.change(is_deleted: true)
    |> Repo.update()
  end

  @doc """
  Edits a message content and updates edited_at timestamp.
  """
  def edit_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Ecto.Changeset.change(edited_at: DateTime.utc_now())
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Searches messages in a room by content.
  Returns messages matching the search query.
  """
  def search_messages(room_id, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    include_deleted = Keyword.get(opts, :include_deleted, false)

    search_pattern = "%#{query}%"

    Message
    |> where([m], m.room_id == ^room_id)
    |> where([m], ilike(m.content, ^search_pattern))
    |> maybe_filter_deleted(include_deleted)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end
end
