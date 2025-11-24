defmodule RogsComm.Messages do
  @moduledoc """
  Provides the data access API for chat messages, including
  listing, creation, and lifecycle helpers.
  """

  import Ecto.Query, warn: false

  alias RogsComm.Repo
  alias RogsComm.Messages.Message
  alias RogsComm.Cache.MessageCache

  @doc """
  Lists messages for a room, returning them in chronological order.
  Excludes deleted messages by default.

  Uses cache when available to reduce database load.
  """
  def list_messages(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    include_deleted = Keyword.get(opts, :include_deleted, false)
    use_cache = Keyword.get(opts, :use_cache, true)

    # Try cache first if enabled and not including deleted messages
    if use_cache and not include_deleted do
      case MessageCache.get(room_id) do
        {:ok, cached_messages} ->
          # Return cached messages if they meet the limit requirement
          if length(cached_messages) >= limit do
            Enum.take(cached_messages, limit)
          else
            # Cache miss or insufficient data, fetch from DB
            fetch_and_cache_messages(room_id, limit, include_deleted)
          end

        :not_found ->
          # Cache miss, fetch from DB
          fetch_and_cache_messages(room_id, limit, include_deleted)
      end
    else
      # Bypass cache (e.g., when including deleted messages)
      fetch_messages(room_id, limit, include_deleted)
    end
  end

  defp fetch_messages(room_id, limit, include_deleted) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> maybe_filter_deleted(include_deleted)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> subquery()
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  defp fetch_and_cache_messages(room_id, limit, include_deleted) do
    messages = fetch_messages(room_id, limit, include_deleted)
    # Cache the results (only if not including deleted)
    if not include_deleted do
      MessageCache.put(room_id, messages)
    end

    messages
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
        |> subquery()
        |> order_by([m], asc: m.inserted_at)
        |> Repo.all()

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
  Invalidates cache for the room after creation.
  """
  def create_message(attrs \\ %{}) do
    case %Message{}
         |> Message.changeset(attrs)
         |> Repo.insert() do
      {:ok, _message} = result ->
        # Invalidate cache for the room
        if Map.has_key?(attrs, :room_id) do
          MessageCache.invalidate(attrs.room_id)
        end

        result

      error ->
        error
    end
  end

  @doc """
  Updates a message.
  Invalidates cache for the room after update.
  """
  def update_message(%Message{} = message, attrs) do
    case message
         |> Message.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_message} = result ->
        # Invalidate cache for the room
        MessageCache.invalidate(updated_message.room_id)
        result

      error ->
        error
    end
  end

  @doc """
  Deletes a message (hard delete).
  Invalidates cache for the room after deletion.
  """
  def delete_message(%Message{} = message) do
    room_id = message.room_id

    case Repo.delete(message) do
      {:ok, _deleted_message} = result ->
        # Invalidate cache for the room
        MessageCache.invalidate(room_id)
        result

      error ->
        error
    end
  end

  @doc """
  Soft deletes a message by marking it as deleted.
  Invalidates cache for the room after soft deletion.
  """
  def soft_delete_message(%Message{} = message) do
    case message
         |> Ecto.Changeset.change(is_deleted: true)
         |> Repo.update() do
      {:ok, updated_message} = result ->
        # Invalidate cache for the room
        MessageCache.invalidate(updated_message.room_id)
        result

      error ->
        error
    end
  end

  @doc """
  Edits a message content and updates edited_at timestamp.
  Invalidates cache for the room after edit.
  """
  def edit_message(%Message{} = message, attrs) do
    case message
         |> Message.changeset(attrs)
         |> Ecto.Changeset.change(edited_at: DateTime.utc_now())
         |> Repo.update() do
      {:ok, updated_message} = result ->
        # Invalidate cache for the room
        MessageCache.invalidate(updated_message.room_id)
        result

      error ->
        error
    end
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
