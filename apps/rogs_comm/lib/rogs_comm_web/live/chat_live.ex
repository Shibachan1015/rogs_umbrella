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

  @rtc_connect_delay 400
  @rtc_max_retries 3
  @rtc_retry_delay 2000

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
          |> assign(:rtc_state, default_rtc_state())
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
      user_id = socket.assigns[:current_user_id]

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
      user_id = socket.assigns[:current_user_id]

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

  def handle_event("start_audio", _params, socket) do
    state = socket.assigns.rtc_state

    if state.connecting? or state.connected? do
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:rtc_state, %{
          state
          | connecting?: true,
            status_message: "音声チャネルを初期化しています...",
            error: nil,
            retry_count: 0
        })
        |> push_event("rtc:start", %{room_id: socket.assigns.room_id})

      Process.send_after(self(), :rtc_connected, @rtc_connect_delay)

      {:noreply, socket}
    end
  end

  def handle_event("stop_audio", _params, socket) do
    state = socket.assigns.rtc_state

    if not state.connected? and not state.connecting? do
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:rtc_state, %{
          state
          | connected?: false,
            connecting?: false,
            status_message: "音声チャネルを切断しました",
            error: nil,
            retry_count: 0
        })
        |> push_event("rtc:stop", %{room_id: socket.assigns.room_id})

      {:noreply, socket}
    end
  end

  def handle_event("toggle_mic", _params, socket) do
    state = socket.assigns.rtc_state

    if state.connected? do
      new_state =
        state
        |> Map.update!(:mic_muted?, fn muted -> !muted end)
        |> Map.put(:status_message, mic_status_message(!state.mic_muted?))

      socket =
        socket
        |> assign(:rtc_state, new_state)
        |> push_event("rtc:toggle-mic", %{muted: new_state.mic_muted?})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_speakers", _params, socket) do
    state = socket.assigns.rtc_state

    if state.connected? do
      new_state =
        state
        |> Map.update!(:speakers_muted?, fn muted -> !muted end)
        |> Map.put(:status_message, speaker_status_message(!state.speakers_muted?))

      socket =
        socket
        |> assign(:rtc_state, new_state)
        |> push_event("rtc:toggle-speakers", %{muted: new_state.speakers_muted?})

      {:noreply, socket}
    else
      {:noreply, socket}
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

  def handle_info(:rtc_connected, socket) do
    state = socket.assigns.rtc_state

    if state.connecting? do
      {:noreply,
       assign(socket, :rtc_state, %{
         state
         | connecting?: false,
           connected?: true,
           status_message: "音声チャネルが接続されました",
           error: nil,
           retry_count: 0
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:rtc_error, reason}, socket) do
    state = socket.assigns.rtc_state

    if state.connecting? do
      retry_count = Map.get(state, :retry_count, 0)

      if retry_count < @rtc_max_retries do
        Logger.warning("ChatLive: WebRTC connection failed, retrying",
          room_id: socket.assigns.room_id,
          reason: reason,
          retry_count: retry_count + 1
        )

        # Schedule retry
        Process.send_after(self(), :rtc_retry, @rtc_retry_delay)

        {:noreply,
         assign(socket, :rtc_state, %{
           state
           | connecting?: true,
             status_message: "接続に失敗しました。再試行中... (#{retry_count + 1}/#{@rtc_max_retries})",
             error: reason,
             retry_count: retry_count + 1
         })}
      else
        Logger.error("ChatLive: WebRTC connection failed after max retries",
          room_id: socket.assigns.room_id,
          reason: reason,
          retry_count: retry_count
        )

        {:noreply,
         assign(socket, :rtc_state, %{
           state
           | connecting?: false,
             connected?: false,
             status_message: "接続に失敗しました。しばらくしてから再試行してください。",
             error: reason,
             retry_count: 0
         })}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:rtc_retry, socket) do
    state = socket.assigns.rtc_state

    if state.connecting? and not state.connected? do
      socket =
        socket
        |> assign(:rtc_state, %{
          state
          | status_message: "音声チャネルを再試行しています...",
            error: nil
        })
        |> push_event("rtc:start", %{room_id: socket.assigns.room_id})

      Process.send_after(self(), :rtc_connected, @rtc_connect_delay)

      {:noreply, socket}
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

  defp default_rtc_state do
    %{
      connected?: false,
      connecting?: false,
      mic_muted?: false,
      speakers_muted?: false,
      status_message: "未接続",
      error: nil,
      retry_count: 0
    }
  end

  defp rtc_status_label(%{connected?: true}), do: "接続中"
  defp rtc_status_label(%{connecting?: true}), do: "接続準備中"
  defp rtc_status_label(_state), do: "未接続"

  defp rtc_state_pill(%{connected?: true}), do: "CONNECTED"
  defp rtc_state_pill(%{connecting?: true}), do: "LINKING"
  defp rtc_state_pill(_state), do: "IDLE"

  defp rtc_data_state(%{connected?: true}), do: "connected"
  defp rtc_data_state(%{connecting?: true}), do: "connecting"
  defp rtc_data_state(_state), do: "idle"

  defp mic_toggle_label(%{mic_muted?: true}), do: "マイク: ミュート"
  defp mic_toggle_label(_state), do: "マイク: ON"

  defp speaker_toggle_label(%{speakers_muted?: true}), do: "スピーカー: OFF"
  defp speaker_toggle_label(_state), do: "スピーカー: ON"

  defp rtc_participant_hint(%{connected?: true}), do: "音声同期中"
  defp rtc_participant_hint(%{connecting?: true}), do: "接続準備中"
  defp rtc_participant_hint(_state), do: "待機中"

  defp search_state_label(true), do: "ON"
  defp search_state_label(_), do: "OFF"

  defp search_state_screen_text(true), do: "検索モードが有効になりました"
  defp search_state_screen_text(_), do: "検索モードは無効です"

  defp rtc_state_status_text(%{connected?: true}), do: "音声チャネルは接続済みです"
  defp rtc_state_status_text(%{connecting?: true}), do: "音声チャネルを接続中です"
  defp rtc_state_status_text(_), do: "音声チャネルは未接続です"

  defp mic_status_message(true), do: "マイクをミュートにしました"
  defp mic_status_message(false), do: "マイクを有効にしました"

  defp speaker_status_message(true), do: "スピーカーをミュートにしました"
  defp speaker_status_message(false), do: "スピーカーを有効にしました"

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
      <div class="landing-body">
        <section class="torii-hero my-6 md:my-10" aria-labelledby="chat-hero-title">
          <div class="torii-lines" aria-hidden="true"></div>
          <div class="relative z-10 text-center md:text-left max-w-4xl mx-auto space-y-4">
            <% share_link = url(~p"/rooms/#{@room_id}/chat") %>
            <p class="text-sm uppercase tracking-[0.5em] text-[var(--color-landing-text-secondary)]">
              Humans are one of the Myriad Gods
            </p>
            <h1
              id="chat-hero-title"
              class="text-3xl md:text-5xl font-bold text-[var(--color-landing-pale)]"
            >
              コミュニケーションの杜
            </h1>
            <p class="text-base md:text-lg text-[var(--color-landing-text-secondary)] leading-relaxed">
              神環記の相談フェーズを支えるリアルタイムチャット。和紙のようなやわらかさと朱のアクセントで、プレイヤーの声を丁寧に繋ぎます。
            </p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center md:justify-start">
              <.link navigate={~p"/rooms"} class="cta-button cta-solid focus-ring">
                ルーム一覧へ
              </.link>
              <a href="#chat-panel" class="cta-button cta-outline focus-ring">
                現在のルームを見る
              </a>
              <button
                type="button"
                id="room-share-button"
                class="cta-button cta-outline focus-ring flex items-center gap-2 justify-center"
                phx-hook="CopyLinkHook"
                data-copy-url={share_link}
              >
                <span aria-hidden="true">🔗</span>
                <span data-copy-label>ルームリンクをコピー</span>
                <span data-copy-feedback class="sr-only" aria-live="polite"></span>
              </button>
            </div>
            <div
              class="flex flex-wrap gap-3 mt-4 justify-center md:justify-start text-xs tracking-[0.2em]"
              style="color: var(--color-landing-text-secondary);"
              id="chat-state-tracker"
              phx-hook="ChatStateHook"
              data-search-mode={if(@search_mode, do: "on", else: "off")}
              data-rtc-state={rtc_data_state(@rtc_state)}
            >
              <span class="trds-pill">Room: {@room.name}</span>
              <span class="trds-pill">
                Online: {Enum.count(@presences)}
              </span>
              <span
                class={["trds-pill", if(@search_mode, do: "trds-pill--gold", else: "")]}
                data-pill="search"
              >
                Search {search_state_label(@search_mode)}
              </span>
              <span
                class={["trds-pill", if(@rtc_state.connected?, do: "trds-pill--gold", else: "")]}
                data-pill="audio"
              >
                Audio: {rtc_state_pill(@rtc_state)}
              </span>
            </div>
            <div aria-live="polite" class="sr-only">
              {search_state_screen_text(@search_mode)}。{rtc_state_status_text(@rtc_state)}
            </div>
          </div>
        </section>

        <section id="chat-panel" class="px-4 md:px-6 pb-10" aria-labelledby="chat-section-title">
          <h2 id="chat-section-title" class="sr-only">チャットエリア</h2>

          <div
            id="chat-root"
            class="trds-glass-panel flex flex-col xl:flex-row gap-6"
            data-room-id={@room_id}
            data-display-name={@display_name}
            phx-hook="TypingHook"
            role="region"
            aria-label={"チャットルーム #{@room.name}"}
          >
            <aside class="w-full xl:w-72 space-y-5" aria-label="チャット補助パネル">
              <div class="trds-glass-panel">
                <h3
                  class="text-sm uppercase tracking-[0.4em] mb-4"
                  style="color: var(--color-landing-text-primary);"
                >
                  Rooms
                </h3>
                <nav class="space-y-3" aria-label="ルーム一覧" role="list">
                  <.link
                    :for={room <- @rooms}
                    role="listitem"
                    aria-current={if room.id == @room_id, do: "true", else: "false"}
                    navigate={~p"/rooms/#{room.id}/chat"}
                    class={[
                      "block rounded-lg px-3 py-2 text-sm font-medium transition-all duration-200",
                      "trds-focusable border border-transparent",
                      room.id == @room_id && "trds-pill trds-pill--gold",
                      room.id != @room_id &&
                        "trds-pill hover:trds-pill--gold"
                    ]}
                  >
                    <span class="font-semibold">{room.name}</span>
                    <p class="text-xs opacity-70 mt-1 truncate">{room.topic || "トピック未設定"}</p>
                  </.link>
                </nav>
              </div>

              <div class="trds-glass-panel">
                <h3
                  class="text-sm uppercase tracking-[0.4em] mb-3"
                  style="color: var(--color-landing-text-primary);"
                >
                  Display name
                </h3>
                <.form
                  for={@name_form}
                  phx-submit="set_name"
                  id="display-name-form"
                  class="space-y-3"
                  aria-labelledby="display-name-label"
                >
                  <label id="display-name-label" class="sr-only">表示名</label>
                  <.input
                    field={@name_form[:display_name]}
                    type="text"
                    placeholder="匿名"
                    class="trds-focusable"
                    style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                  />
                  <button
                    type="submit"
                    class="w-full cta-button cta-solid trds-focusable text-sm"
                    aria-label="表示名を更新"
                  >
                    更新
                  </button>
                </.form>
              </div>

              <div class="trds-glass-panel">
                <h3
                  class="text-sm uppercase tracking-[0.4em] mb-3"
                  style="color: var(--color-landing-text-primary);"
                >
                  メッセージ検索
                </h3>
                <.form
                  for={@search_form}
                  phx-submit="search"
                  phx-change="search"
                  id="search-form"
                  class="space-y-3"
                  aria-labelledby="search-label"
                >
                  <label id="search-label" class="sr-only">メッセージ検索</label>
                  <.input
                    field={@search_form[:query]}
                    type="text"
                    placeholder="検索..."
                    autocomplete="off"
                    class="trds-focusable"
                    style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                  />
                  <button
                    :if={@search_mode}
                    type="button"
                    phx-click="clear_search"
                    class="w-full cta-button cta-outline trds-focusable text-sm"
                    aria-label="検索結果をクリア"
                  >
                    検索をクリア
                  </button>
                </.form>
              </div>

              <div
                id="audio-panel"
                class="trds-glass-panel space-y-4"
                phx-hook="WebRTCHook"
                data-room-id={@room_id}
                aria-live="polite"
              >
                <div>
                  <p
                    class="text-xs uppercase tracking-[0.4em] mb-1"
                    style="color: var(--color-landing-text-secondary);"
                  >
                    音声チャネル
                  </p>
                  <p class="text-lg font-semibold" style="color: var(--color-landing-gold);">
                    {rtc_status_label(@rtc_state)}
                  </p>
                  <p class="text-sm mt-1" style="color: var(--color-landing-text-secondary);">
                    {@rtc_state.status_message}
                  </p>
                </div>

                <div class="flex gap-3">
                  <button
                    type="button"
                    phx-click="start_audio"
                    disabled={@rtc_state.connecting? or @rtc_state.connected?}
                    class={[
                      "flex-1 cta-button cta-solid trds-focusable text-xs uppercase tracking-[0.3em]",
                      (@rtc_state.connecting? or @rtc_state.connected?) &&
                        "opacity-60 cursor-not-allowed"
                    ]}
                  >
                    接続
                  </button>
                  <button
                    type="button"
                    phx-click="stop_audio"
                    disabled={not @rtc_state.connected? and not @rtc_state.connecting?}
                    class={[
                      "flex-1 cta-button cta-outline trds-focusable",
                      (not @rtc_state.connected? and not @rtc_state.connecting?) &&
                        "opacity-60 cursor-not-allowed"
                    ]}
                  >
                    切断
                  </button>
                </div>

                <div class="flex flex-col sm:flex-row gap-2 text-xs uppercase tracking-[0.2em]">
                  <button
                    type="button"
                    phx-click="toggle_mic"
                    disabled={!@rtc_state.connected?}
                    class={[
                      "flex-1 trds-pill trds-focusable transition-all",
                      @rtc_state.connected? && "hover:trds-pill--gold",
                      !@rtc_state.connected? && "opacity-50 cursor-not-allowed"
                    ]}
                  >
                    {mic_toggle_label(@rtc_state)}
                  </button>
                  <button
                    type="button"
                    phx-click="toggle_speakers"
                    disabled={!@rtc_state.connected?}
                    class={[
                      "flex-1 trds-pill trds-focusable transition-all",
                      @rtc_state.connected? && "hover:trds-pill--gold",
                      !@rtc_state.connected? && "opacity-50 cursor-not-allowed"
                    ]}
                  >
                    {speaker_toggle_label(@rtc_state)}
                  </button>
                </div>

                <div>
                  <p
                    class="text-xs uppercase tracking-[0.4em] mb-2"
                    style="color: var(--color-landing-text-primary);"
                  >
                    参加者ステータス
                  </p>
                  <ul class="space-y-2" role="list">
                    <li
                      :for={{user_id, meta} <- list_presences(@presences)}
                      role="listitem"
                      class="trds-pill flex items-center justify-between"
                    >
                      <span>{meta.user_email || "匿名"}</span>
                      <span class="text-xs" style="color: var(--color-landing-text-secondary);">
                        {rtc_participant_hint(@rtc_state)}
                      </span>
                    </li>
                    <li
                      :if={Enum.empty?(@presences)}
                      class="text-xs"
                      style="color: var(--color-landing-text-secondary);"
                    >
                      オンラインのプレイヤーはいません
                    </li>
                  </ul>
                </div>
              </div>

              <div class="trds-glass-panel">
                <h3
                  class="text-sm uppercase tracking-[0.4em] mb-3"
                  style="color: var(--color-landing-text-primary);"
                >
                  Online ({Enum.count(@presences)})
                </h3>
                <div class="space-y-2" role="list" aria-label="オンラインユーザー">
                  <div
                    :for={{user_id, meta} <- list_presences(@presences)}
                    role="listitem"
                    class="trds-pill flex items-center justify-between"
                  >
                    <span>{meta.user_email || "匿名"}</span>
                    <span class="flex items-center gap-1 text-xs uppercase tracking-[0.2em]">
                      <span
                        class="h-2 w-2 rounded-full inline-block"
                        style="background-color: var(--color-landing-gold);"
                        aria-hidden="true"
                      >
                      </span>
                      Online
                    </span>
                  </div>
                  <p
                    :if={Enum.empty?(@presences)}
                    class="text-xs opacity-70"
                    style="color: var(--color-landing-text-secondary);"
                  >
                    現在オンラインのユーザーはいません。
                  </p>
                </div>
              </div>
            </aside>

            <div class="flex-1 flex flex-col trds-glass-panel overflow-hidden">
              <div
                class="border-b px-4 py-3 shadow-md flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3"
                style="border-color: var(--trds-outline-soft);"
              >
                <div>
                  <p
                    class="text-xs uppercase tracking-[0.4em]"
                    style="color: var(--color-landing-text-secondary);"
                  >
                    現在のルーム
                  </p>
                  <h3 class="text-2xl font-semibold" style="color: var(--color-landing-text-primary);">
                    {@room.name}
                  </h3>
                  <p class="text-sm mt-1" style="color: var(--color-landing-text-secondary);">
                    {@room.topic}
                  </p>
                </div>
                <div class="space-y-2 text-right">
                  <div
                    :if={@search_mode}
                    class="trds-pill trds-pill--gold text-sm"
                  >
                    検索モード: {length(@search_results)}件
                  </div>
                  <div class="text-xs" style="color: var(--color-landing-text-secondary);">
                    メッセージ数: {Enum.count(@streams.messages)}
                  </div>
                </div>
              </div>

              <div
                class="flex-1 overflow-y-auto px-2 md:px-4 py-4 space-y-4"
                id="messages"
                phx-update="stream"
                phx-hook="ChatScrollHook"
                role="list"
                aria-live="polite"
                aria-atomic="false"
              >
                <div
                  :if={@has_older_messages && Enum.count(@streams.messages) > 0 && !@search_mode}
                  class="text-center py-2"
                >
                  <button
                    phx-click="load_older_messages"
                    phx-value-message_id={@streams.messages |> Enum.at(0) |> elem(1) |> Map.get(:id)}
                    class="cta-button cta-outline trds-focusable text-sm"
                    aria-label="古いメッセージを読み込む"
                  >
                    古いメッセージを読み込む
                  </button>
                </div>
                <div
                  :if={@search_mode && Enum.count(@streams.messages) == 0}
                  class="text-center py-8 trds-glass-panel"
                  role="status"
                  aria-live="polite"
                  style="color: var(--color-landing-text-secondary);"
                >
                  <div class="text-4xl mb-2" aria-hidden="true">🔍</div>
                  <p>検索結果が見つかりませんでした</p>
                </div>
                <article
                  :for={{id, message} <- @streams.messages}
                  id={id}
                  class="flex flex-col group trds-glass-panel hover:shadow-md transition-all duration-200 message-enter"
                  role="listitem"
                  aria-label={"#{message.user_email} #{message.inserted_at && Calendar.strftime(message.inserted_at, "%H:%M")}"}
                >
                  <div class="flex items-center justify-between mb-2">
                    <div class="text-sm" style="color: var(--color-landing-text-secondary);">
                      <span
                        class="font-semibold pl-2"
                        style="color: var(--color-landing-text-primary); border-left: 2px solid var(--trds-outline-strong);"
                      >
                        {message.user_email}
                      </span>
                      <span class="ml-2">
                        {message.inserted_at && Calendar.strftime(message.inserted_at, "%H:%M")}
                      </span>
                      <span
                        :if={Map.get(message, :edited_at)}
                        class="ml-2 text-xs"
                        style="color: var(--color-landing-gold);"
                      >
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
                        class="trds-pill trds-focusable text-xs hover:trds-pill--gold transition-colors duration-200"
                        aria-label="メッセージを編集"
                      >
                        編集
                      </button>
                      <button
                        phx-click="delete_message"
                        phx-value-message_id={message.id}
                        class="trds-pill trds-focusable text-xs hover:trds-pill--gold transition-colors duration-200"
                        aria-label="メッセージを削除"
                      >
                        削除
                      </button>
                    </div>
                  </div>
                  <p
                    :if={!@search_mode}
                    class="text-base leading-relaxed"
                    style="color: var(--color-landing-text-primary);"
                  >
                    {message.content}
                  </p>
                  <p
                    :if={@search_mode}
                    class="text-base leading-relaxed"
                    phx-no-format
                    style="color: var(--color-landing-text-primary);"
                  >
                    {raw(highlight_search_term(message.content, @search_form.params["query"] || ""))}
                  </p>
                </article>
                <div
                  :if={map_size(@typing_users) > 0}
                  class="trds-pill text-sm italic mt-2 typing-indicator"
                  role="status"
                  aria-live="polite"
                  style="color: var(--color-landing-text-secondary);"
                >
                  <span
                    class="typing-indicator"
                    aria-hidden="true"
                    style="color: var(--color-landing-gold);"
                  >
                    ✍️
                  </span>
                  {Enum.join(Enum.map(@typing_users, fn {_id, email} -> email end), ", ")}が入力中...
                </div>
              </div>

              <div
                class="border-t px-2 md:px-4 py-3 shadow-lg"
                style="border-color: var(--trds-outline-soft);"
              >
                <.form
                  for={@form}
                  id="chat-form"
                  phx-submit="submit"
                  aria-label="メッセージ送信フォーム"
                >
                  <div class="flex flex-col sm:flex-row gap-2">
                    <.input
                      field={@form[:content]}
                      type="text"
                      placeholder="メッセージを入力..."
                      class="flex-1 text-sm md:text-base trds-focusable rounded-lg"
                      style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                      autocomplete="off"
                      aria-label="メッセージ入力"
                    />
                    <button
                      type="submit"
                      class="px-4 md:px-6 py-2 cta-button cta-solid trds-focusable text-sm md:text-base whitespace-nowrap"
                    >
                      送信
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
