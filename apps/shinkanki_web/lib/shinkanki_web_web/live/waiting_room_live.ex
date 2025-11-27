defmodule ShinkankiWebWeb.WaitingRoomLive do
  @moduledoc """
  待機室画面 - ゲーム開始前の準備画面
  - プレイヤー一覧
  - 準備OK機能
  - チャット
  - 全員準備完了でゲーム開始
  """
  use ShinkankiWebWeb, :live_view

  alias RogsComm.Rooms
  alias RogsComm.Messages
  alias RogsComm.PubSub, as: CommPubSub
  alias Shinkanki

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # ログイン状態を確認
    current_user = socket.assigns[:current_user]

    # 本番環境では未ログインの場合はログインページにリダイレクト
    # 開発環境ではゲストモードを許可
    if current_user == nil and Mix.env() == :prod do
      {:ok,
       socket
       |> put_flash(:error, "ログインしてください")
       |> push_navigate(to: ~p"/users/log_in")}
    else
      # 開発環境用のゲストユーザー
      effective_user =
        current_user ||
          %{id: Ecto.UUID.generate(), email: "dev@guest.local"}

      # ルームを取得
      case Rooms.fetch_room_by_slug(slug) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "ルームが見つかりません")
           |> push_navigate(to: ~p"/lobby")}

        room ->
          mount_with_room(room, effective_user, socket)
      end
    end
  end

  defp mount_with_room(room, current_user, socket) do
    # ユーザー情報
    user_id = current_user.id
    user_email = current_user.email

    # ゲームセッションを開始または取得
    room_id = room.id

    case Shinkanki.get_current_state(room_id) do
      nil ->
        case Shinkanki.start_game_session(room_id) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          _ -> :ok
        end

      _game ->
        :ok
    end

    # プレイヤーとして参加
    player_name = user_email
    Shinkanki.join_player(room_id, user_id, player_name)

    # ゲーム状態を取得
    game_state = Shinkanki.get_current_state(room_id) || %{}

    # チャットフォーム
    chat_form = to_form(%{"body" => "", "author" => user_email}, as: :chat)

    socket =
      socket
      |> assign(:room, room)
      |> assign(:room_id, room_id)
      |> assign(:user_id, user_id)
      |> assign(:user_email, user_email)
      |> assign(:current_user, current_user)
      |> assign(:current_scope, nil)
      |> assign(:game_state, game_state)
      |> assign(:players, get_players(game_state))
      |> assign(:is_ready, get_player_ready(game_state, user_id))
      |> assign(:all_ready, all_players_ready?(game_state))
      |> assign(:is_host, is_host?(game_state, user_id))
      |> assign(:can_start, can_start_game?(game_state))
      |> assign(:chat_form, chat_form)

    socket =
      if connected?(socket) do
        # PubSub購読
        chat_topic = "room:#{room_id}"
        Phoenix.PubSub.subscribe(CommPubSub, chat_topic)

        game_topic = "shinkanki:game:#{room_id}"
        Phoenix.PubSub.subscribe(Shinkanki.PubSub, game_topic)

        # メッセージ読み込み
        messages = load_messages(room_id)
        stream(socket, :chat_messages, messages, reset: true)
      else
        stream(socket, :chat_messages, [], reset: true)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="waiting-room-container">
        <!-- ヘッダー -->
        <header class="waiting-room-header">
          <.link navigate={~p"/lobby"} class="back-link">
            ← ロビーに戻る
          </.link>
          <div class="room-info">
            <h1 class="room-name">{@room.name}</h1>
            <%= if @room.topic do %>
              <p class="room-topic">{@room.topic}</p>
            <% end %>
          </div>
        </header>

        <div class="waiting-room-content">
          <!-- 左カラム: プレイヤー一覧 + 準備 -->
          <aside class="players-panel">
            <h2 class="panel-title">プレイヤー</h2>

            <div class="players-list">
              <%= for player <- @players do %>
                <.player_card
                  player={player}
                  is_current_user={player.id == @user_id}
                  is_host={player.is_host}
                />
              <% end %>

              <!-- 空きスロット -->
              <%= for _i <- 1..(@room.max_participants - length(@players)) do %>
                <div class="player-slot empty">
                  <span class="slot-icon">⭕</span>
                  <span class="slot-text">空き</span>
                </div>
              <% end %>
            </div>

            <div class="ready-section">
              <%= if @is_ready do %>
                <button
                  type="button"
                  class="ready-btn ready-btn--active"
                  phx-click="toggle_ready"
                >
                  ✓ 準備完了
                </button>
              <% else %>
                <button
                  type="button"
                  class="ready-btn"
                  phx-click="toggle_ready"
                >
                  準備OK
                </button>
              <% end %>
            </div>

            <!-- ゲーム開始ボタン（ホストのみ） -->
            <%= if @is_host do %>
              <div class="start-section">
                <%= if @can_start && @all_ready do %>
                  <button
                    type="button"
                    class="start-game-btn"
                    phx-click="start_game"
                  >
                    🎮 ゲーム開始
                  </button>
                <% else %>
                  <button
                    type="button"
                    class="start-game-btn start-game-btn--disabled"
                    disabled
                  >
                    <%= cond do %>
                      <% !@can_start -> %>
                        プレイヤーが必要です
                      <% !@all_ready -> %>
                        全員の準備を待っています...
                      <% true -> %>
                        ゲーム開始
                    <% end %>
                  </button>
                <% end %>
              </div>
            <% else %>
              <div class="waiting-for-host">
                <p>ホストがゲーム開始を押すまでお待ちください</p>
              </div>
            <% end %>
          </aside>

          <!-- 右カラム: チャット -->
          <section class="chat-panel">
            <h2 class="panel-title">チャット</h2>

            <div
              id="chat-messages"
              phx-update="stream"
              class="chat-messages"
              phx-hook="ChatScroll"
            >
              <div
                :for={{id, msg} <- @streams.chat_messages}
                id={id}
                class="chat-message"
              >
                <div class="message-header">
                  <span class="message-author">{msg.user_email || msg.author}</span>
                  <span class="message-time">{format_time(msg.inserted_at)}</span>
                </div>
                <p class="message-body">{msg.content || msg.body}</p>
              </div>
            </div>

            <.form for={@chat_form} id="chat-form" phx-submit="send_chat" class="chat-form">
              <.input
                field={@chat_form[:body]}
                type="textarea"
                placeholder="メッセージを入力..."
                class="chat-input"
              />
              <button type="submit" class="send-btn">送信</button>
            </.form>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # プレイヤーカードコンポーネント
  defp player_card(assigns) do
    ~H"""
    <div class={[
      "player-card",
      @is_current_user && "player-card--current",
      @player.is_ready && "player-card--ready"
    ]}>
      <div class="player-avatar">
        <%= if @is_host do %>
          <span class="host-badge">👑</span>
        <% end %>
        <span class="avatar-icon">👤</span>
      </div>
      <div class="player-info">
        <span class="player-name">
          {@player.name}
          <%= if @is_current_user do %>
            <span class="you-badge">（あなた）</span>
          <% end %>
        </span>
        <span class={["ready-status", @player.is_ready && "ready-status--ready"]}>
          <%= if @player.is_ready, do: "✓ 準備完了", else: "準備中..." %>
        </span>
      </div>
    </div>
    """
  end

  # イベントハンドラ
  @impl true
  def handle_event("toggle_ready", _params, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    case Shinkanki.toggle_waiting_ready(room_id, user_id) do
      {:ok, game} ->
        {:noreply,
         socket
         |> assign(:game_state, game)
         |> assign(:players, get_players(game))
         |> assign(:is_ready, get_player_ready(game, user_id))
         |> assign(:all_ready, all_players_ready?(game))}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    room_id = socket.assigns.room_id

    case Shinkanki.start_game(room_id) do
      {:ok, _game} ->
        # ゲーム画面に遷移
        {:noreply, push_navigate(socket, to: ~p"/game/#{room_id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "ゲーム開始エラー: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("send_chat", %{"chat" => %{"body" => body}}, socket) do
    body = String.trim(body)

    if body != "" do
      room_id = socket.assigns.room_id
      user_id = socket.assigns.user_id
      user_email = socket.assigns.user_email

      case Messages.create_message(%{
             content: body,
             room_id: room_id,
             user_id: user_id,
             user_email: user_email
           }) do
        {:ok, _message} ->
          chat_form = to_form(%{"body" => "", "author" => user_email}, as: :chat)
          {:noreply, assign(socket, :chat_form, chat_form)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # PubSub ハンドラ
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "new_message", payload: payload}, socket) do
    message = %{
      id: payload.id || Ecto.UUID.generate(),
      user_email: payload.user_email || "anonymous",
      content: payload.content,
      inserted_at: payload.inserted_at || DateTime.utc_now()
    }

    {:noreply, stream(socket, :chat_messages, [message])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_state_updated", payload: game}, socket) do
    user_id = socket.assigns.user_id

    # ゲームが開始されたら遷移
    if game.status == :playing do
      {:noreply, push_navigate(socket, to: ~p"/game/#{socket.assigns.room_id}")}
    else
      {:noreply,
       socket
       |> assign(:game_state, game)
       |> assign(:players, get_players(game))
       |> assign(:is_ready, get_player_ready(game, user_id))
       |> assign(:all_ready, all_players_ready?(game))
       |> assign(:can_start, can_start_game?(game))}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ヘルパー関数
  defp get_players(%{players: players, player_order: order}) when is_map(players) do
    Enum.map(order, fn player_id ->
      player = Map.get(players, player_id, %{})

      %{
        id: player_id,
        name: player.name || "Player",
        is_ready: player.is_ready || false,
        is_host: List.first(order) == player_id
      }
    end)
  end

  defp get_players(_), do: []

  defp get_player_ready(%{players: players}, user_id) when is_map(players) do
    case Map.get(players, user_id) do
      nil -> false
      player -> player.is_ready || false
    end
  end

  defp get_player_ready(_, _), do: false

  defp all_players_ready?(%{players: players, player_order: order})
       when is_map(players) and length(order) > 0 do
    Enum.all?(order, fn player_id ->
      case Map.get(players, player_id) do
        nil -> false
        player -> player.is_ready == true
      end
    end)
  end

  defp all_players_ready?(_), do: false

  defp is_host?(%{player_order: [first | _]}, user_id), do: first == user_id
  defp is_host?(_, _), do: false

  defp can_start_game?(%{player_order: order}) when length(order) >= 1, do: true
  defp can_start_game?(_), do: false

  defp load_messages(room_id) do
    case Messages.list_messages(room_id, limit: 50) do
      messages when is_list(messages) ->
        Enum.map(messages, fn msg ->
          %{
            id: msg.id,
            user_email: msg.user_email,
            content: msg.content,
            inserted_at: msg.inserted_at
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  defp format_time(_), do: ""
end
