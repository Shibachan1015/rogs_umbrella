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

  on_mount {RogsCommWeb.UserAuthHooks, :assign_current_user}

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Room not found")
         |> redirect(to: ~p"/")}

      room ->
        display_name = socket.assigns[:display_name] || "anonymous"

        socket =
          socket
          |> assign(:room, room)
          |> assign(:room_id, room_id)
          |> assign(:rooms, Rooms.list_rooms())
          |> assign(:form, to_form(%{"content" => ""}))
          |> assign(:name_form, to_form(%{"display_name" => display_name}))
          |> assign(:search_form, to_form(%{"query" => ""}))
          |> assign(:presences, %{})
          |> assign(:typing_users, %{})
          |> assign(:has_older_messages, true)
          |> assign(:search_mode, false)
          |> assign(:search_results, [])
          |> stream_configure(:messages, dom_id: &"message-#{&1.id}")

        if connected?(socket) do
          topic = topic(room_id)
          RogsCommWeb.Endpoint.subscribe(topic)
          messages = Messages.list_messages(room_id, limit: 50)

          presences =
            try do
              Presence.list(topic)
            rescue
              _ -> %{}
            end

          socket =
            socket
            |> assign(:presences, presences)
            |> stream(:messages, messages)

          {:ok, socket}
        else
          {:ok,
           socket
           |> assign(:presences, %{})
           |> stream(:messages, [])}
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
      user_id = socket.assigns[:current_user_id] || Ecto.UUID.generate()

      user_email =
        socket.assigns[:current_user_email] || socket.assigns[:display_name] || "anonymous"

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

        {:error, changeset} ->
          error_message =
            case changeset.errors do
              [{:content, {msg, _}}] -> "メッセージ: #{msg}"
              [{:content, msg}] when is_binary(msg) -> "メッセージ: #{msg}"
              _ -> "メッセージの送信に失敗しました"
            end

          {:noreply, put_flash(socket, :error, error_message)}
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

  def handle_event("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:current_user_id]

    trimmed_content = String.trim(content)

    if trimmed_content == "" do
      {:noreply, put_flash(socket, :error, "メッセージ内容を入力してください")}
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

              RogsCommWeb.Endpoint.broadcast(topic(room_id), "message_edited", payload)
              {:noreply, socket}

            {:error, changeset} ->
              error_message =
                case changeset.errors do
                  [{:content, {msg, _}}] -> "メッセージ: #{msg}"
                  [{:content, msg}] when is_binary(msg) -> "メッセージ: #{msg}"
                  _ -> "メッセージの編集に失敗しました"
                end

              {:noreply, put_flash(socket, :error, error_message)}
          end

        message when message.room_id != room_id ->
          {:noreply, put_flash(socket, :error, "このルームのメッセージではありません")}

        message when message.user_id != user_id ->
          {:noreply, put_flash(socket, :error, "自分のメッセージのみ編集できます")}

        _ ->
          {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
      end
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
  end

  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns[:current_user_id]

    case Messages.get_message!(message_id) do
      message when message.room_id == room_id and message.user_id == user_id ->
        case Messages.soft_delete_message(message) do
          {:ok, _deleted_message} ->
            RogsCommWeb.Endpoint.broadcast(topic(room_id), "message_deleted", %{id: message_id})
            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "メッセージの削除に失敗しました")}
        end

      message when message.room_id != room_id ->
        {:noreply, put_flash(socket, :error, "このルームのメッセージではありません")}

      message when message.user_id != user_id ->
        {:noreply, put_flash(socket, :error, "自分のメッセージのみ削除できます")}

      _ ->
        {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
  end

  def handle_event("load_older_messages", %{"message_id" => message_id}, socket) do
    # Load older messages directly from the context
    room_id = socket.assigns.room_id
    older_messages = Messages.list_messages_before(room_id, message_id, limit: 50)

    socket =
      if length(older_messages) > 0 do
        socket
        |> stream(:messages, older_messages, at: 0)
        |> assign(:has_older_messages, length(older_messages) == 50)
      else
        socket
        |> assign(:has_older_messages, false)
      end

    {:noreply, socket}
  rescue
    Ecto.NoResultsError ->
      {:noreply, assign(socket, :has_older_messages, false)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    trimmed_query = String.trim(query)

    if trimmed_query == "" do
      # Clear search and return to normal view
      room_id = socket.assigns.room_id
      messages = Messages.list_messages(room_id, limit: 50)

      {:noreply,
       socket
       |> assign(:search_mode, false)
       |> assign(:search_results, [])
       |> assign(:search_form, to_form(%{"query" => ""}))
       |> stream(:messages, messages, reset: true)}
    else
      # Perform search
      room_id = socket.assigns.room_id
      results = Messages.search_messages(room_id, trimmed_query, limit: 50)

      {:noreply,
       socket
       |> assign(:search_mode, true)
       |> assign(:search_results, results)
       |> assign(:search_form, to_form(%{"query" => trimmed_query}))
       |> stream(:messages, results, reset: true)}
    end
  end

  def handle_event("clear_search", _params, socket) do
    room_id = socket.assigns.room_id
    messages = Messages.list_messages(room_id, limit: 50)

    {:noreply,
     socket
     |> assign(:search_mode, false)
     |> assign(:search_results, [])
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> stream(:messages, messages, reset: true)}
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
        inserted_at: payload.inserted_at,
        edited_at: Map.get(payload, :edited_at)
      }

      {:noreply, stream(socket, :messages, [message])}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "message_edited", payload: payload},
        socket
      ) do
    room_topic = topic(socket.assigns.room_id)

    if topic == room_topic do
      # Update existing message in stream
      {:noreply,
       socket
       |> stream_insert(
         :messages,
         %{
           id: payload.id,
           content: payload.content,
           edited_at: payload.edited_at
         },
         at: -1
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "message_deleted", payload: payload},
        socket
      ) do
    room_topic = topic(socket.assigns.room_id)

    if topic == room_topic do
      {:noreply, stream_delete(socket, :messages, payload.id)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "user_typing", payload: payload},
        socket
      ) do
    room_topic = topic(socket.assigns.room_id)

    if topic == room_topic do
      typing_users =
        socket.assigns.typing_users
        |> Map.put(payload.user_id, payload.user_email)

      {:noreply, assign(socket, :typing_users, typing_users)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "user_stopped_typing", payload: payload},
        socket
      ) do
    room_topic = topic(socket.assigns.room_id)

    if topic == room_topic do
      typing_users = Map.delete(socket.assigns.typing_users, payload.user_id)

      {:noreply, assign(socket, :typing_users, typing_users)}
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
      inserted_at: message.inserted_at,
      edited_at: message.edited_at
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
        phx-hook="TypingHook"
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
              メッセージ検索
            </h2>
            <.form
              for={@search_form}
              phx-submit="search"
              phx-change="search"
              id="search-form"
              class="mt-2 space-y-2"
            >
              <.input
                field={@search_form[:query]}
                type="text"
                placeholder="検索..."
                autocomplete="off"
              />
              <button
                :if={@search_mode}
                type="button"
                phx-click="clear_search"
                class="w-full rounded-md bg-gray-500 px-3 py-2 text-sm text-white hover:bg-gray-600"
              >
                検索をクリア
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
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-xl font-semibold text-gray-900">{@room.name}</h1>
                <p class="text-sm text-gray-500">{@room.topic}</p>
              </div>
              <div :if={@search_mode} class="text-sm text-blue-600">
                検索モード: {length(@search_results)}件見つかりました
              </div>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto px-4 py-4 space-y-4" id="messages" phx-update="stream">
            <div
              :if={@has_older_messages && Enum.count(@streams.messages) > 0 && !@search_mode}
              class="text-center py-2"
            >
              <button
                phx-click="load_older_messages"
                phx-value-message_id={@streams.messages |> Enum.at(0) |> elem(1) |> Map.get(:id)}
                class="text-sm text-blue-600 hover:text-blue-800 px-4 py-2 rounded border border-blue-300 hover:bg-blue-50"
              >
                古いメッセージを読み込む
              </button>
            </div>
            <div
              :if={@search_mode && Enum.count(@streams.messages) == 0}
              class="text-center py-8 text-gray-500"
            >
              検索結果が見つかりませんでした
            </div>
            <div
              :for={{id, message} <- @streams.messages}
              id={id}
              class="flex flex-col group hover:bg-gray-50 p-2 rounded"
            >
              <div class="flex items-center justify-between">
                <div class="text-sm text-gray-500">
                  <span class="font-semibold text-gray-900">{message.user_email}</span>
                  <span class="ml-2">
                    {message.inserted_at && Calendar.strftime(message.inserted_at, "%H:%M")}
                  </span>
                  <span :if={Map.get(message, :edited_at)} class="ml-2 text-xs text-gray-400">
                    (編集済み)
                  </span>
                </div>
                <div
                  :if={Map.get(message, :user_id) == @current_user_id}
                  class="opacity-0 group-hover:opacity-100 flex gap-2"
                >
                  <button
                    phx-click="edit_message"
                    phx-value-message_id={message.id}
                    class="text-xs text-blue-600 hover:text-blue-800"
                  >
                    編集
                  </button>
                  <button
                    phx-click="delete_message"
                    phx-value-message_id={message.id}
                    class="text-xs text-red-600 hover:text-red-800"
                  >
                    削除
                  </button>
                </div>
              </div>
              <p class="text-gray-800 text-base">{message.content}</p>
            </div>
            <div :if={map_size(@typing_users) > 0} class="text-sm text-gray-500 italic mt-2">
              {Enum.join(Enum.map(@typing_users, fn {_id, email} -> email end), ", ")}が入力中...
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
