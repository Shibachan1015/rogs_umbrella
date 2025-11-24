defmodule RogsCommWeb.ChatChannel do
  @moduledoc """
  Channel for real-time chat within a room.
  """

  use RogsCommWeb, :channel

  require Logger

  alias RogsComm.Messages
  alias RogsComm.Rooms
  alias RogsCommWeb.Presence
  alias RogsCommWeb.RateLimiter

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        Logger.warning("ChatChannel: Attempted to join non-existent room", room_id: room_id)
        {:error, %{reason: "room not found"}}

      room ->
        topic = "room:#{room_id}"

        # Check if room is full
        current_participants =
          try do
            Presence.list(topic) |> map_size()
          rescue
            error ->
              Logger.error("ChatChannel: Failed to list presences",
                room_id: room_id,
                error: inspect(error)
              )

              0
          end

        if current_participants >= room.max_participants do
          Logger.info("ChatChannel: Room is full",
            room_id: room_id,
            current_participants: current_participants,
            max_participants: room.max_participants
          )

          {:error, %{reason: "room is full"}}
        else
          user_id = socket.assigns[:user_id] || Ecto.UUID.generate()
          user_email = socket.assigns[:user_email] || "anonymous"

          socket =
            socket
            |> assign(:room_id, room_id)
            |> assign(:user_id, user_id)
            |> assign(:user_email, user_email)

          send(self(), :after_join)
          messages = Messages.list_messages(room_id, limit: 50)
          {:ok, %{messages: messages}, socket}
        end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    topic = "room:#{socket.assigns.room_id}"
    user_id = socket.assigns.user_id
    user_email = socket.assigns.user_email

    {:ok, _} =
      Presence.track(
        self(),
        topic,
        user_id,
        %{
          user_id: user_id,
          user_email: user_email,
          online_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      )

    push(socket, "presence_state", Presence.list(topic))
    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff", payload: _diff}, socket) do
    push(socket, "presence_diff", Presence.list("room:#{socket.assigns.room_id}"))
    {:noreply, socket}
  end

  @impl true
  def handle_in("new_message", %{"content" => content}, socket) when is_binary(content) do
    user_id = socket.assigns[:user_id] || Ecto.UUID.generate()

    # Rate limit check: 10 messages per 5 seconds per user
    case RateLimiter.check(user_id, limit: 10, window_seconds: 5) do
      {:ok, :allowed} ->
        room_id = socket.assigns.room_id
        user_email = socket.assigns[:user_email] || "anonymous"

        params = %{
          content: content,
          room_id: room_id,
          user_id: user_id,
          user_email: user_email
        }

        trimmed_content = String.trim(content)

        if trimmed_content == "" do
          {:reply, {:error, %{reason: "message content cannot be empty"}}, socket}
        else
          params = Map.put(params, :content, trimmed_content)

          case Messages.create_message(params) do
            {:ok, message} ->
              payload = %{
                id: message.id,
                content: message.content,
                user_id: message.user_id,
                user_email: message.user_email,
                inserted_at: message.inserted_at
              }

              broadcast(socket, "new_message", payload)
              {:noreply, socket}

            {:error, changeset} ->
              reason =
                case changeset.errors do
                  [{:content, {msg, _}}] -> "message #{msg}"
                  [{:content, msg}] when is_binary(msg) -> "message #{msg}"
                  _ -> "failed to create message"
                end

              Logger.error("ChatChannel: Failed to create message",
                user_id: user_id,
                room_id: room_id,
                errors: inspect(changeset.errors)
              )

              {:reply, {:error, %{reason: reason}}, socket}
          end
        end

      {:error, :rate_limited} ->
        Logger.warning("ChatChannel: Rate limit exceeded",
          user_id: user_id,
          room_id: socket.assigns.room_id
        )

        {:reply, {:error, %{reason: "rate limit exceeded. please wait a moment"}}, socket}
    end
  end

  def handle_in("new_message", _params, socket) do
    {:reply, {:error, %{reason: "invalid parameters"}}, socket}
  end

  @impl true
  def handle_in("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    trimmed_content = String.trim(content)

    if trimmed_content == "" do
      {:reply, {:error, %{reason: "message content cannot be empty"}}, socket}
    else
      case Messages.get_message!(message_id) do
        message when message.room_id == room_id and message.user_id == user_id ->
          case Messages.edit_message(message, %{content: trimmed_content}) do
            {:ok, updated_message} ->
              payload = %{
                id: updated_message.id,
                content: updated_message.content,
                edited_at: updated_message.edited_at
              }

              broadcast(socket, "message_edited", payload)
              {:noreply, socket}

            {:error, changeset} ->
              reason =
                case changeset.errors do
                  [{:content, {msg, _}}] -> "message #{msg}"
                  [{:content, msg}] when is_binary(msg) -> "message #{msg}"
                  _ -> "failed to edit message"
                end

              Logger.error("ChatChannel: Failed to edit message",
                user_id: user_id,
                message_id: message_id,
                room_id: room_id,
                errors: inspect(changeset.errors)
              )

              {:reply, {:error, %{reason: reason}}, socket}
          end

        message when message.room_id != room_id ->
          Logger.warning("ChatChannel: Attempted to edit message from different room",
            user_id: user_id,
            message_id: message_id,
            message_room_id: message.room_id,
            current_room_id: room_id
          )

          {:reply, {:error, %{reason: "message not found in this room"}}, socket}

        message when message.user_id != user_id ->
          Logger.warning("ChatChannel: Attempted to edit another user's message",
            user_id: user_id,
            message_id: message_id,
            message_owner_id: message.user_id
          )

          {:reply, {:error, %{reason: "you can only edit your own messages"}}, socket}

        _ ->
          Logger.warning("ChatChannel: Attempted to edit unknown message",
            user_id: user_id,
            message_id: message_id
          )

          {:reply, {:error, %{reason: "message not found"}}, socket}
      end
    end
  rescue
    Ecto.NoResultsError ->
      user_id = socket.assigns.user_id

      Logger.warning("ChatChannel: Message not found for edit",
        user_id: socket.assigns.user_id,
        message_id: message_id
      )

      {:reply, {:error, %{reason: "message not found"}}, socket}
  end

  @impl true
  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Messages.get_message!(message_id) do
      message when message.room_id == room_id and message.user_id == user_id ->
        case Messages.soft_delete_message(message) do
          {:ok, _deleted_message} ->
            broadcast(socket, "message_deleted", %{id: message_id})
            {:noreply, socket}

          {:error, changeset} ->
            Logger.error("ChatChannel: Failed to delete message",
              user_id: user_id,
              message_id: message_id,
              room_id: room_id,
              errors: inspect(changeset.errors)
            )

            {:reply, {:error, %{reason: "failed to delete message"}}, socket}
        end

      message when message.room_id != room_id ->
        Logger.warning("ChatChannel: Attempted to delete message from different room",
          user_id: user_id,
          message_id: message_id,
          message_room_id: message.room_id,
          current_room_id: room_id
        )

        {:reply, {:error, %{reason: "message not found in this room"}}, socket}

      message when message.user_id != user_id ->
        Logger.warning("ChatChannel: Attempted to delete another user's message",
          user_id: user_id,
          message_id: message_id,
          message_owner_id: message.user_id
        )

        {:reply, {:error, %{reason: "you can only delete your own messages"}}, socket}

      _ ->
        Logger.warning("ChatChannel: Attempted to delete unknown message",
          user_id: user_id,
          message_id: message_id
        )

        {:reply, {:error, %{reason: "message not found"}}, socket}
    end
  rescue
    Ecto.NoResultsError ->
      user_id = socket.assigns.user_id

      Logger.warning("ChatChannel: Message not found for delete",
        user_id: socket.assigns.user_id,
        message_id: message_id
      )

      {:reply, {:error, %{reason: "message not found"}}, socket}
  end

  @impl true
  def handle_in("typing_start", _params, socket) do
    payload = %{
      user_id: socket.assigns.user_id,
      user_email: socket.assigns.user_email
    }

    broadcast_from(socket, "user_typing", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_stop", _params, socket) do
    payload = %{
      user_id: socket.assigns.user_id,
      user_email: socket.assigns.user_email
    }

    broadcast_from(socket, "user_stopped_typing", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("load_older_messages", %{"message_id" => message_id}, socket) do
    room_id = socket.assigns.room_id
    older_messages = Messages.list_messages_before(room_id, message_id, limit: 50)

    payload = %{
      messages: older_messages,
      has_more: length(older_messages) == 50
    }

    push(socket, "older_messages_loaded", payload)
    {:noreply, socket}
  end

  def handle_in("load_older_messages", _params, socket) do
    {:reply, {:error, %{reason: "message_id is required"}}, socket}
  end
end
