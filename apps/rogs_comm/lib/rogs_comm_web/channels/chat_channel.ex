defmodule RogsCommWeb.ChatChannel do
  @moduledoc """
  Channel for real-time chat within a room.
  """

  use RogsCommWeb, :channel

  alias RogsComm.Messages
  alias RogsComm.Rooms
  alias RogsCommWeb.Presence

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        {:error, %{reason: "room not found"}}

      _room ->
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
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:user_id] || Ecto.UUID.generate()
    user_email = socket.assigns[:user_email] || "anonymous"

    params = %{
      content: content,
      room_id: room_id,
      user_id: user_id,
      user_email: user_email
    }

    with {:ok, message} <- Messages.create_message(params) do
      payload = %{
        id: message.id,
        content: message.content,
        user_id: message.user_id,
        user_email: message.user_email,
        inserted_at: message.inserted_at
      }

      broadcast(socket, "new_message", payload)
      {:noreply, socket}
    else
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "failed to create message"}}, socket}
    end
  end

  def handle_in("new_message", _params, socket) do
    {:reply, {:error, %{reason: "invalid parameters"}}, socket}
  end
end
