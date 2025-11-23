defmodule RogsCommWeb.ChatChannel do
  @moduledoc """
  Channel for real-time chat within a room.
  """

  use RogsCommWeb, :channel

  alias RogsComm.Messages
  alias RogsComm.Rooms

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        {:error, %{reason: "room not found"}}

      _room ->
        messages = Messages.list_messages(room_id, limit: 50)
        {:ok, %{messages: messages}, assign(socket, :room_id, room_id)}
    end
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
