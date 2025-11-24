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

  require Logger

  alias RogsComm.Messages
  alias RogsComm.Rooms
  alias RogsCommWeb.Presence

  on_mount {RogsCommWeb.UserAuthHooks, :assign_current_user}

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    case Rooms.fetch_room(room_id) do
      nil ->
        Logger.warning("ChatLive: Attempted to access non-existent room", room_id: room_id)

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

          Logger.error("ChatLive: Failed to create message",
            user_id: user_id,
            room_id: room_id,
            errors: inspect(changeset.errors)
          )

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

              Logger.error("ChatLive: Failed to edit message",
                user_id: user_id,
                message_id: message_id,
                room_id: room_id,
                errors: inspect(changeset.errors)
              )

              {:noreply, put_flash(socket, :error, error_message)}
          end

        message when message.room_id != room_id ->
          Logger.warning("ChatLive: Attempted to edit message from different room",
            user_id: user_id,
            message_id: message_id,
            message_room_id: message.room_id,
            current_room_id: room_id
          )

          {:noreply, put_flash(socket, :error, "このルームのメッセージではありません")}

        message when message.user_id != user_id ->
          Logger.warning("ChatLive: Attempted to edit another user's message",
            user_id: user_id,
            message_id: message_id,
            message_owner_id: message.user_id
          )

          {:noreply, put_flash(socket, :error, "自分のメッセージのみ編集できます")}

        _ ->
          Logger.warning("ChatLive: Attempted to edit unknown message",
            user_id: user_id,
            message_id: message_id
          )

          {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
      end
    end
  rescue
    Ecto.NoResultsError ->
      Logger.warning("ChatLive: Message not found for edit",
        user_id: user_id,
        message_id: message_id
      )

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

          {:error, changeset} ->
            Logger.error("ChatLive: Failed to delete message",
              user_id: user_id,
              message_id: message_id,
              room_id: room_id,
              errors: inspect(changeset.errors)
            )

            {:noreply, put_flash(socket, :error, "メッセージの削除に失敗しました")}
        end

      message when message.room_id != room_id ->
        Logger.warning("ChatLive: Attempted to delete message from different room",
          user_id: user_id,
          message_id: message_id,
          message_room_id: message.room_id,
          current_room_id: room_id
        )

        {:noreply, put_flash(socket, :error, "このルームのメッセージではありません")}

      message when message.user_id != user_id ->
        Logger.warning("ChatLive: Attempted to delete another user's message",
          user_id: user_id,
          message_id: message_id,
          message_owner_id: message.user_id
        )

        {:noreply, put_flash(socket, :error, "自分のメッセージのみ削除できます")}

      _ ->
        Logger.warning("ChatLive: Attempted to delete unknown message",
          user_id: user_id,
          message_id: message_id
        )

        {:noreply, put_flash(socket, :error, "メッセージが見つかりません")}
    end
  rescue
    Ecto.NoResultsError ->
      Logger.warning("ChatLive: Message not found for delete",
        user_id: user_id,
        message_id: message_id
      )

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

  defp highlight_search_term(content, query) when is_binary(content) and is_binary(query) do
    if String.trim(query) == "" do
      content
    else
      # Escape special regex characters in query
      escaped_query = Regex.escape(query)
      pattern = ~r/#{escaped_query}/iu

      Regex.replace(pattern, content, fn match ->
        ~s(<mark class="bg-kin/30 text-sumi px-1 rounded border border-kin">#{match}</mark>)
      end)
    end
  end

  defp highlight_search_term(content, _query), do: content

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div
        id="chat-root"
        class="flex h-screen flex-col md:flex-row bg-washi"
        data-room-id={@room_id}
        data-display-name={@display_name}
        phx-hook="TypingHook"
      >
        <aside class="w-full md:w-64 border-r-2 border-sumi bg-washi-dark px-4 py-6 space-y-6 overflow-y-auto sidebar-enter">
          <div>
            <h2 class="text-sm font-semibold text-sumi uppercase tracking-widest mb-3 border-b-2 border-sumi pb-2">
              ルーム一覧
            </h2>
            <nav class="mt-3 space-y-2">
              <.link
                :for={room <- @rooms}
                navigate={~p"/rooms/#{room.id}/chat"}
                class={[
                  "block rounded-lg px-3 py-2 text-sm font-medium transition-all duration-200 ofuda-card",
                  room.id == @room_id && "bg-shu text-washi border-2 border-sumi",
                  room.id != @room_id && "hover:bg-washi hover:shadow-md"
                ]}
              >
                <div class={["font-semibold", room.id == @room_id && "text-washi", room.id != @room_id && "text-sumi"]}>
                  {room.name}
                </div>
                <p class={["text-xs truncate mt-1", room.id == @room_id && "text-washi/80", room.id != @room_id && "text-sumi-light"]}>
                  {room.topic}
                </p>
              </.link>
            </nav>
          </div>

          <div>
            <h2 class="text-sm font-semibold text-sumi uppercase tracking-widest mb-3 border-b-2 border-sumi pb-2">
              表示名
            </h2>
            <.form
              for={@name_form}
              phx-submit="set_name"
              id="display-name-form"
              class="mt-2 space-y-2"
            >
              <.input
                field={@name_form[:display_name]}
                type="text"
                placeholder="匿名"
                class="bg-washi border-2 border-sumi text-sumi focus:border-shu focus:ring-2 focus:ring-shu/20"
              />
              <button
                type="submit"
                class="w-full hanko-button text-sm"
              >
                更新
              </button>
            </.form>
          </div>

          <div>
            <h2 class="text-sm font-semibold text-sumi uppercase tracking-widest mb-3 border-b-2 border-sumi pb-2">
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
                class="bg-washi border-2 border-sumi text-sumi focus:border-matsu focus:ring-2 focus:ring-matsu/20"
              />
              <button
                :if={@search_mode}
                type="button"
                phx-click="clear_search"
                class="w-full rounded-md bg-sumi-light text-washi px-3 py-2 text-sm hover:bg-sumi transition-colors duration-200"
              >
                検索をクリア
              </button>
            </.form>
          </div>

          <div>
            <h2 class="text-sm font-semibold text-sumi uppercase tracking-widest mb-3 border-b-2 border-sumi pb-2">
              オンライン ({Enum.count(@presences)})
            </h2>
            <div class="mt-3 space-y-2">
              <div
                :for={{user_id, meta} <- list_presences(@presences)}
                class="flex items-center gap-2 text-sm bg-washi px-2 py-1 rounded border border-sumi/20"
              >
                <div class="h-2 w-2 rounded-full bg-matsu border border-sumi"></div>
                <span class="text-sumi">{meta.user_email || "匿名"}</span>
              </div>
            </div>
          </div>
        </aside>

        <div class="flex flex-1 flex-col bg-washi">
          <div class="bg-washi-dark border-b-2 border-sumi px-4 py-3 shadow-md">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-xl font-semibold text-sumi border-l-4 border-shu pl-3">{@room.name}</h1>
                <p class="text-sm text-sumi-light mt-1">{@room.topic}</p>
              </div>
              <div :if={@search_mode} class="text-sm text-shu bg-shu/10 px-3 py-1 rounded border border-shu">
                検索モード: {length(@search_results)}件見つかりました
              </div>
            </div>
          </div>

          <div
            class="flex-1 overflow-y-auto px-2 md:px-4 py-4 space-y-4"
            id="messages"
            phx-update="stream"
            phx-hook="ChatScrollHook"
          >
            <div
              :if={@has_older_messages && Enum.count(@streams.messages) > 0 && !@search_mode}
              class="text-center py-2"
            >
              <button
                phx-click="load_older_messages"
                phx-value-message_id={@streams.messages |> Enum.at(0) |> elem(1) |> Map.get(:id)}
                class="text-sm text-matsu hover:text-shu px-4 py-2 rounded border-2 border-matsu hover:border-shu bg-washi hover:bg-washi-dark transition-all duration-200"
              >
                古いメッセージを読み込む
              </button>
            </div>
            <div
              :if={@search_mode && Enum.count(@streams.messages) == 0}
              class="text-center py-8 text-sumi-light"
            >
              <div class="text-4xl mb-2">🔍</div>
              <p>検索結果が見つかりませんでした</p>
            </div>
            <div
              :for={{id, message} <- @streams.messages}
              id={id}
              class="flex flex-col group ofuda-card hover:shadow-md transition-all duration-200 message-enter"
            >
              <div class="flex items-center justify-between mb-2">
                <div class="text-sm text-sumi-light">
                  <span class="font-semibold text-sumi border-l-2 border-matsu pl-2">{message.user_email}</span>
                  <span class="ml-2">
                    {message.inserted_at && Calendar.strftime(message.inserted_at, "%H:%M")}
                  </span>
                  <span :if={Map.get(message, :edited_at)} class="ml-2 text-xs text-kohaku">
                    (編集済み)
                  </span>
                </div>
                <div
                  :if={Map.get(message, :user_id) == @current_user_id}
                  class="opacity-0 group-hover:opacity-100 flex gap-2 transition-opacity duration-200"
                >
                  <button
                    phx-click="edit_message"
                    phx-value-message_id={message.id}
                    class="text-xs text-matsu hover:text-shu px-2 py-1 rounded border border-matsu hover:border-shu transition-colors duration-200"
                  >
                    編集
                  </button>
                  <button
                    phx-click="delete_message"
                    phx-value-message_id={message.id}
                    class="text-xs text-shu hover:bg-shu hover:text-washi px-2 py-1 rounded border border-shu transition-colors duration-200"
                  >
                    削除
                  </button>
                </div>
              </div>
              <p
                class="text-sumi text-base leading-relaxed"
                :if={!@search_mode}
              >
                {message.content}
              </p>
              <p
                class="text-sumi text-base leading-relaxed"
                :if={@search_mode}
                phx-no-format
              >
                {raw(highlight_search_term(message.content, @search_form.params["query"] || ""))}
              </p>
            </div>
            <div :if={map_size(@typing_users) > 0} class="text-sm text-sumi-light italic mt-2 bg-sakura/20 px-3 py-2 rounded border border-sakura typing-indicator">
              <span class="text-sakura typing-indicator">✍️</span> {Enum.join(Enum.map(@typing_users, fn {_id, email} -> email end), ", ")}が入力中...
            </div>
          </div>

          <div class="bg-washi-dark border-t-2 border-sumi px-2 md:px-4 py-3 shadow-lg">
            <.form for={@form} id="chat-form" phx-submit="submit">
              <div class="flex space-x-2">
                <.input
                  field={@form[:content]}
                  type="text"
                  placeholder="メッセージを入力..."
                  class="flex-1 text-sm md:text-base bg-washi border-2 border-sumi text-sumi focus:border-shu focus:ring-2 focus:ring-shu/20 rounded-lg"
                  autocomplete="off"
                />
                <button
                  type="submit"
                  class="px-4 md:px-6 py-2 hanko-button text-sm md:text-base whitespace-nowrap"
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
