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
  alias RogsCommWeb.Presence

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
          |> assign(:rooms, Rooms.list_rooms())
          |> assign_new(:display_name, fn -> "anonymous" end)
          |> assign(:form, to_form(%{"content" => ""}))
          |> assign(
            :name_form,
            to_form(%{"display_name" => socket.assigns[:display_name] || "anonymous"})
          )
          |> stream_configure(:messages, dom_id: &"message-#{&1.id}")

        if connected?(socket) do
          topic = topic(room_id)
          RogsCommWeb.Endpoint.subscribe(topic)
          messages = Messages.list_messages(room_id, limit: 50)

          socket =
            socket
            |> assign(:presences, Presence.list(topic))
            |> stream(:messages, messages)

          {:ok, socket}
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
      user_email = socket.assigns[:display_name] || "anonymous"

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

  def handle_event("set_name", %{"display_name" => name}, socket) do
    trimmed =
      name
      |> to_string()
      |> String.trim()

    display_name = if trimmed == "", do: "anonymous", else: trimmed

    {:noreply,
     socket
     |> assign(:display_name, display_name)
     |> assign(:name_form, to_form(%{"display_name" => display_name}))}
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

  @impl true
  def handle_info(%{event: "presence_diff", payload: _diff}, socket) do
    topic = topic(socket.assigns.room_id)
    presences = Presence.list(topic)
    {:noreply, assign(socket, :presences, presences)}
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

  defp list_presences(presences) do
    presences
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      {user_id, meta}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div
        id="chat-root"
        class="flex h-screen"
        data-room-id={@room_id}
        data-display-name={@display_name}
      >
        <aside class="w-64 border-r bg-base-200 px-4 py-6 space-y-6">
          <div>
            <h2 class="text-sm font-semibold text-base-content/70 uppercase tracking-widest">
              Rooms
            </h2>
            <nav class="mt-3 space-y-2">
              <.link
                :for={room <- @rooms}
                navigate={~p"/rooms/#{room.id}/chat"}
                class={[
                  "block rounded-lg px-3 py-2 text-sm font-medium transition",
                  room.id == @room_id && "bg-base-100 shadow-sm",
                  room.id != @room_id && "hover:bg-base-300/60"
                ]}
              >
                <div class="text-base-content">{room.name}</div>
                <p class="text-xs text-base-content/60 truncate">{room.topic}</p>
              </.link>
            </nav>
          </div>

          <div>
            <h2 class="text-sm font-semibold text-base-content/70 uppercase tracking-widest">
              Display name
            </h2>
            <.form
              for={@name_form}
              phx-submit="set_name"
              id="display-name-form"
              class="mt-2 space-y-2"
            >
              <.input field={@name_form[:display_name]} type="text" placeholder="anonymous" />
              <button
                type="submit"
                class="w-full rounded-md bg-base-content/80 px-3 py-2 text-sm text-base-100"
              >
                更新
              </button>
            </.form>
          </div>

          <div>
            <h2 class="text-sm font-semibold text-base-content/70 uppercase tracking-widest">
              Online ({Enum.count(@presences)})
            </h2>
            <div class="mt-3 space-y-2">
              <div
                :for={{user_id, meta} <- list_presences(@presences)}
                class="flex items-center gap-2 text-sm"
              >
                <div class="h-2 w-2 rounded-full bg-green-500"></div>
                <span class="text-base-content">{meta.user_email || "anonymous"}</span>
              </div>
            </div>
          </div>
        </aside>

        <div class="flex flex-1 flex-col">
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
      </div>
    </Layouts.app>
    """
  end
end
