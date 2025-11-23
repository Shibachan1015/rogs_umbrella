defmodule RogsCommWeb.ChatLive do
  @moduledoc """
  LiveView for a room chat interface.

  ⚠️ NOTE:
    This LiveView provides a developer-facing chat UI so that the
    `rogs_comm` worktree can exercise its messaging backend. The
    final player-facing UI is expected to live in the `rogs-ui`
    / `shinkanki_web` worktree and should replace this module when
    the design system implementation is ready.
  """

  use RogsCommWeb, :live_view

  alias RogsComm.Messages
  alias RogsComm.Rooms

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Room not found")
         |> redirect(to: ~p"/")}

      room ->
        socket =
          socket
          |> assign(:room, room)
          |> assign(:room_id, room_id)
          |> assign(:form, to_form(%{"content" => ""}))
          |> stream_configure(:messages, dom_id: &"message-#{&1.id}")

        if connected?(socket) do
          topic = topic(room_id)
          RogsCommWeb.Endpoint.subscribe(topic)
          messages = Messages.list_messages(room_id, limit: 50)
          {:ok, stream(socket, :messages, messages)}
        else
          {:ok, socket}
        end
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Room ID is required")
     |> redirect(to: ~p"/")}
  end

  @impl true
  def handle_event("submit", %{"content" => content}, socket) do
    trimmed = String.trim(content || "")

    if trimmed == "" do
      {:noreply, socket}
    else
      room_id = socket.assigns.room_id
      user_id = socket.assigns[:user_id] || Ecto.UUID.generate()
      user_email = socket.assigns[:user_email] || "anonymous"

      params = %{
        content: trimmed,
        room_id: room_id,
        user_id: user_id,
        user_email: user_email
      }

      case Messages.create_message(params) do
        {:ok, message} ->
          payload = broadcast_payload(message)
          RogsCommWeb.Endpoint.broadcast(topic(room_id), "new_message", payload)

          {:noreply, assign(socket, :form, to_form(%{"content" => ""}))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "メッセージの送信に失敗しました")}
      end
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "new_message", payload: payload},
        socket
      ) do
    room_topic = topic(socket.assigns.room_id)

    if topic == room_topic do
      message = %{
        id: payload.id,
        content: payload.content,
        user_id: payload.user_id,
        user_email: payload.user_email,
        inserted_at: payload.inserted_at
      }

      {:noreply, stream(socket, :messages, [message])}
    else
      {:noreply, socket}
    end
  end

  defp broadcast_payload(message) do
    %{
      id: message.id,
      content: message.content,
      user_id: message.user_id,
      user_email: message.user_email,
      inserted_at: message.inserted_at
    }
  end

  defp topic(room_id), do: "room:#{room_id}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col h-screen">
        <div class="bg-white shadow-sm border-b px-4 py-3">
          <h1 class="text-xl font-semibold text-gray-900">{@room.name}</h1>
          <p class="text-sm text-gray-500">{@room.topic}</p>
        </div>

        <div class="flex-1 overflow-y-auto px-4 py-4 space-y-4" id="messages" phx-update="stream">
          <div :for={{id, message} <- @streams.messages} id={id} class="flex flex-col">
            <div class="text-sm text-gray-500">
              <span class="font-semibold text-gray-900">{message.user_email}</span>
              <span class="ml-2">
                {message.inserted_at && Calendar.strftime(message.inserted_at, "%H:%M")}
              </span>
            </div>
            <p class="text-gray-800 text-base">{message.content}</p>
          </div>
        </div>

        <div class="bg-white border-t px-4 py-3">
          <.form for={@form} id="chat-form" phx-submit="submit">
            <div class="flex space-x-2">
              <.input
                field={@form[:content]}
                type="text"
                placeholder="メッセージを入力..."
                class="flex-1"
                autocomplete="off"
              />
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                送信
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
