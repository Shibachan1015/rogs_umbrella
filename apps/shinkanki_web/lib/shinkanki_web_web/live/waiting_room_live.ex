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
  alias RogsIdentity.Accounts.User
  alias RogsIdentity.Friends
  alias RogsIdentity.Messages, as: UserMessages
  alias RogsIdentity.Presence
  alias Shinkanki
  alias Shinkanki.Games

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
       |> push_navigate(to: ~p"/users/log-in")}
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
    _user_email = current_user.email

    # 表示名とアバターを取得
    display_name = User.display_name(current_user)
    avatar = User.avatar(current_user)

    # ゲームセッションを開始または取得
    room_id = room.id

    case Shinkanki.get_current_state(room_id) do
      nil ->
        # GameServerがまだない場合は新規作成
        case Shinkanki.start_game_session(room_id) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          _ -> :ok
        end

      %{status: :playing} ->
        # ゲームが既に進行中の場合はゲーム画面にリダイレクト
        {:ok,
         socket
         |> put_flash(:info, "ゲームが進行中です")
         |> push_navigate(to: ~p"/game/#{room.slug}")}
        |> then(&{:redirect, &1})

      %{status: :won} ->
        # ゲーム終了（勝利）の場合はロビーにリダイレクト
        {:ok,
         socket
         |> put_flash(:info, "このルームのゲームは終了しました")
         |> push_navigate(to: ~p"/lobby")}
        |> then(&{:redirect, &1})

      %{status: :lost} ->
        # ゲーム終了（敗北）の場合はロビーにリダイレクト
        {:ok,
         socket
         |> put_flash(:info, "このルームのゲームは終了しました")
         |> push_navigate(to: ~p"/lobby")}
        |> then(&{:redirect, &1})

      _game ->
        # :waiting状態の場合は通常通り続行
        :ok
    end
    |> case do
      {:redirect, result} ->
        result

      :ok ->
        # プレイヤーとして参加（表示名とアバターを使用）
        Shinkanki.join_player(room_id, user_id, display_name, avatar)
        continue_mount_with_room(room, current_user, socket)
    end
  end

  defp continue_mount_with_room(room, current_user, socket) do
    user_id = current_user.id
    user_email = current_user.email
    display_name = User.display_name(current_user)
    room_id = room.id

    # プレイヤーとして参加（既にjoinしているので省略）
    # Shinkanki.join_player(room_id, user_id, display_name, avatar)

    # ゲーム状態を取得
    game_state = Shinkanki.get_current_state(room_id) || %{}

    # チャットフォーム
    chat_form = to_form(%{"body" => "", "author" => display_name}, as: :chat)

    # ルームのアクティビティを更新
    Rooms.touch_activity(room)

    # ルームホストの確認（DBから）
    is_room_host = room.host_id == user_id

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
      |> assign(:is_room_host, is_room_host)
      |> assign(:can_start, can_start_game?(game_state))
      |> assign(:chat_form, chat_form)
      |> assign(:deletion_proposed, room.deletion_proposed_at != nil)
      |> assign(:deletion_votes, room.deletion_votes || [])
      |> assign(:has_voted, user_id in (room.deletion_votes || []))
      |> assign(:is_admin, RogsIdentity.Accounts.admin?(current_user))
      |> assign(:show_invite_panel, false)
      |> assign(:online_friends, [])

    socket =
      if connected?(socket) do
        # PubSub購読
        chat_topic = "room:#{room_id}"
        Phoenix.PubSub.subscribe(CommPubSub, chat_topic)

        game_topic = "shinkanki:game:#{room_id}"
        Phoenix.PubSub.subscribe(Shinkanki.PubSub, game_topic)

        # Presenceをトラック
        Presence.track_user(current_user)

        # オンラインフレンドを取得
        friends = Friends.list_friends(user_id)
        friend_ids = Enum.map(friends, & &1.id)
        online_friend_ids = Presence.online_friend_ids(friend_ids)

        online_friends =
          friends
          |> Enum.filter(&(&1.id in online_friend_ids))

        # メッセージ読み込み
        messages = load_messages(room_id)

        socket
        |> assign(:online_friends, online_friends)
        |> stream(:chat_messages, messages, reset: true)
      else
        stream(socket, :chat_messages, [], reset: true)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
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
                  friendship_status={get_friendship_status(@user_id, player.id)}
                />
              <% end %>

              <!-- 空きスロット（最大4人、既にいるプレイヤー分を除く） -->
              <% empty_slots = max(0, min(4, @room.max_participants) - length(@players)) %>
              <%= if empty_slots > 0 do %>
                <%= for _i <- 1..empty_slots do %>
                  <div class="player-slot empty">
                    <span class="slot-icon">⭕</span>
                    <span class="slot-text">空き</span>
                  </div>
                <% end %>
              <% end %>
            </div>

            <%!-- フレンド招待ボタン --%>
            <%= if length(@online_friends) > 0 do %>
              <div class="invite-section">
                <button
                  type="button"
                  class="invite-friends-btn"
                  phx-click="toggle_invite_panel"
                >
                  📨 フレンドを招待（{length(@online_friends)}人オンライン）
                </button>

                <%= if @show_invite_panel do %>
                  <div class="invite-panel">
                    <%= for friend <- @online_friends do %>
                      <div class="invite-friend-item">
                        <span class="invite-avatar">{friend.avatar || "🎮"}</span>
                        <span class="invite-name">{friend.name}</span>
                        <button
                          type="button"
                          class="invite-btn"
                          phx-click="invite_friend"
                          phx-value-id={friend.id}
                          phx-value-name={friend.name}
                        >
                          招待
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

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

                <!-- AIで補完してスタート（4人未満の場合） -->
                <%= if length(@players) < 4 && length(@players) >= 1 do %>
                  <div class="ai-fill-section">
                    <button
                      type="button"
                      class="ai-fill-btn"
                      phx-click="start_with_ai"
                      data-confirm={"AIプレイヤー#{4 - length(@players)}人を追加してゲームを開始しますか？"}
                    >
                      🤖 AIで補完して開始（{4 - length(@players)}人追加）
                    </button>
                    <p class="ai-fill-hint">
                      人間{length(@players)}人 + AI{4 - length(@players)}人 = 4人でゲーム開始
                    </p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="waiting-for-host">
                <p>ホストがゲーム開始を押すまでお待ちください</p>
              </div>
            <% end %>

            <!-- 削除提案セクション -->
            <div class="deletion-section">
              <%= if @deletion_proposed do %>
                <div class="deletion-proposal-active">
                  <p class="deletion-warning">⚠️ ルーム削除が提案されています</p>
                  <p class="deletion-votes-count">
                    投票: {length(@deletion_votes)}/{div(length(@players), 2) + 1}
                  </p>

                  <%= if @has_voted do %>
                    <button type="button" class="vote-btn vote-btn--voted" disabled>
                      ✓ 投票済み
                    </button>
                  <% else %>
                    <button type="button" class="vote-btn" phx-click="vote_delete">
                      削除に賛成
                    </button>
                  <% end %>

                  <%= if @is_room_host do %>
                    <button type="button" class="cancel-btn" phx-click="cancel_delete">
                      提案をキャンセル
                    </button>
                  <% end %>
                </div>
              <% else %>
                <%= if @is_room_host do %>
                  <button
                    type="button"
                    class="propose-delete-btn"
                    phx-click="propose_delete"
                    data-confirm="本当にルームの削除を提案しますか？過半数の賛成で削除されます。"
                  >
                    🗑️ ルーム削除を提案
                  </button>
                <% end %>
              <% end %>
            </div>

            <!-- 管理者セクション -->
            <%= if @is_admin do %>
              <div class="admin-section">
                <h3 class="admin-title">🛡️ 管理者メニュー</h3>

                <button
                  type="button"
                  class="admin-delete-btn"
                  phx-click="admin_delete_room"
                  data-confirm="管理者権限でルームを即座に削除します。よろしいですか？"
                >
                  🗑️ ルームを強制削除
                </button>

                <div class="admin-player-actions">
                  <p class="admin-subtitle">プレイヤーをBAN:</p>
                  <%= for player <- @players do %>
                    <%= if player.id != @user_id do %>
                      <button
                        type="button"
                        class="admin-ban-btn"
                        phx-click="admin_ban_user"
                        phx-value-user-id={player.id}
                        phx-value-user-name={player.name}
                        data-confirm={"#{player.name} をBANしますか？"}
                      >
                        🚫 {player.name}
                      </button>
                    <% end %>
                  <% end %>
                </div>
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
        <span class="avatar-icon">{@player.avatar || "🎮"}</span>
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
      <%!-- フレンド申請ボタン（自分以外） --%>
      <%= if not @is_current_user do %>
        <div class="player-friend-action">
          <%= case @friendship_status do %>
            <% :none -> %>
              <button
                type="button"
                class="friend-request-btn"
                phx-click="send_friend_request"
                phx-value-id={@player.id}
                phx-value-name={@player.name}
              >
                ＋ フレンド
              </button>
            <% :pending -> %>
              <span class="friend-status pending">申請中</span>
            <% :accepted -> %>
              <span class="friend-status accepted">✓ フレンド</span>
            <% _ -> %>
          <% end %>
        </div>
      <% end %>
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

      {:error, reason} ->
        require Logger
        Logger.error("toggle_ready failed: #{inspect(reason)} for room_id=#{inspect(room_id)}, user_id=#{inspect(user_id)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    room_id = socket.assigns.room_id
    game_state = socket.assigns.game_state

    # プレイヤーのuser_idリストを取得
    user_ids =
      game_state
      |> Map.get(:player_order, [])
      |> Enum.map(fn player_id -> player_id end)

    # DBにゲームセッションを作成
    case Games.create_game_session_from_room(room_id, user_ids) do
      {:ok, _game_session} ->
        # メモリベースのゲームも起動（後方互換性のため）
        case Shinkanki.start_game(room_id) do
          {:ok, _game} ->
            # ゲーム画面に遷移
            {:noreply, push_navigate(socket, to: ~p"/game/#{room_id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "ゲーム開始エラー: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "ゲームセッション作成エラー: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("start_with_ai", _params, socket) do
    room_id = socket.assigns.room_id
    game_state = socket.assigns.game_state

    # プレイヤーのuser_idリストを取得
    user_ids =
      game_state
      |> Map.get(:player_order, [])
      |> Enum.map(fn player_id -> player_id end)

    # メモリベースのゲームでAIを追加して開始
    case Shinkanki.start_game_with_ai(room_id) do
      {:ok, game} ->
        ai_count = Enum.count(game.players, fn {_id, p} -> p.is_ai end)

        # DBにゲームセッションを作成（人間プレイヤー + AI）
        # AIプレイヤーはDBで後から追加される
        case Games.create_game_session_from_room(room_id, user_ids) do
          {:ok, game_session} ->
            # AIプレイヤーを追加
            human_players = Games.get_game_session!(game_session.id) |> Map.get(:players, [])
            Games.fill_with_ai_players(game_session.id, human_players)

            {:noreply,
             socket
             |> put_flash(:info, "AIプレイヤー#{ai_count}人を追加してゲームを開始しました")
             |> push_navigate(to: ~p"/game/#{room_id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "ゲームセッション作成エラー: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "ゲーム開始エラー: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("propose_delete", _params, socket) do
    room = socket.assigns.room
    user_id = socket.assigns.user_id

    case Rooms.propose_deletion(room, user_id) do
      {:ok, updated_room} ->
        {:noreply,
         socket
         |> assign(:room, updated_room)
         |> assign(:deletion_proposed, true)
         |> assign(:deletion_votes, updated_room.deletion_votes)
         |> assign(:has_voted, true)
         |> put_flash(:info, "削除提案を開始しました")}

      {:error, :not_host} ->
        {:noreply, put_flash(socket, :error, "ホストのみが削除を提案できます")}
    end
  end

  @impl true
  def handle_event("vote_delete", _params, socket) do
    room = socket.assigns.room
    user_id = socket.assigns.user_id

    case Rooms.vote_for_deletion(room, user_id) do
      {:ok, updated_room} ->
        # 過半数に達したか確認
        case Rooms.check_and_delete_if_voted(updated_room) do
          {:ok, :deleted} ->
            {:noreply,
             socket
             |> put_flash(:info, "ルームが削除されました")
             |> push_navigate(to: ~p"/lobby")}

          {:ok, :waiting, _count, _required} ->
            {:noreply,
             socket
             |> assign(:room, updated_room)
             |> assign(:deletion_votes, updated_room.deletion_votes)
             |> assign(:has_voted, true)
             |> put_flash(:info, "投票しました")}
        end

      {:error, :already_voted} ->
        {:noreply, put_flash(socket, :error, "すでに投票済みです")}

      {:error, :proposal_expired} ->
        {:noreply,
         socket
         |> assign(:deletion_proposed, false)
         |> assign(:deletion_votes, [])
         |> assign(:has_voted, false)
         |> put_flash(:info, "投票期限が切れました")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "投票できませんでした")}
    end
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    room = socket.assigns.room

    case Rooms.cancel_deletion_proposal(room) do
      {:ok, updated_room} ->
        {:noreply,
         socket
         |> assign(:room, updated_room)
         |> assign(:deletion_proposed, false)
         |> assign(:deletion_votes, [])
         |> assign(:has_voted, false)
         |> put_flash(:info, "削除提案をキャンセルしました")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "キャンセルできませんでした")}
    end
  end

  @impl true
  def handle_event("admin_delete_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    case Rooms.admin_delete_room(room, current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "ルームを削除しました（管理者権限）")
         |> push_navigate(to: ~p"/lobby")}

      {:error, :not_admin} ->
        {:noreply, put_flash(socket, :error, "管理者権限が必要です")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "削除できませんでした")}
    end
  end

  @impl true
  def handle_event("admin_ban_user", %{"user-id" => user_id, "user-name" => user_name}, socket) do
    current_user = socket.assigns.current_user

    case RogsIdentity.Accounts.get_user(user_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "ユーザーが見つかりません")}

      target_user ->
        case RogsIdentity.Accounts.ban_user(current_user, target_user, "管理者によるBAN") do
          {:ok, _} ->
            {:noreply, put_flash(socket, :info, "#{user_name} をBANしました")}

          {:error, :not_admin} ->
            {:noreply, put_flash(socket, :error, "管理者権限が必要です")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "BANできませんでした")}
        end
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

  @impl true
  def handle_event("send_friend_request", %{"id" => addressee_id, "name" => name}, socket) do
    user_id = socket.assigns.user_id

    case Friends.send_friend_request(user_id, addressee_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{name} にフレンド申請を送信しました")
         |> update_players_friendship_status()}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :error, "すでに申請済みです")}

      {:error, :already_friends} ->
        {:noreply, put_flash(socket, :error, "すでにフレンドです")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "申請できませんでした")}
    end
  end

  @impl true
  def handle_event("toggle_invite_panel", _params, socket) do
    {:noreply, assign(socket, :show_invite_panel, !socket.assigns.show_invite_panel)}
  end

  @impl true
  def handle_event("invite_friend", %{"id" => friend_id, "name" => name}, socket) do
    user_id = socket.assigns.user_id
    room = socket.assigns.room

    case UserMessages.invite_to_room(user_id, friend_id, room) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{name} を招待しました")
         |> assign(:show_invite_panel, false)}

      {:error, :not_friends} ->
        {:noreply, put_flash(socket, :error, "フレンドでないと招待できません")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "招待できませんでした")}
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
        avatar: player.avatar || "🎮",
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

  # フレンド関係のステータスを取得
  defp get_friendship_status(user_id, other_id) when user_id == other_id, do: :self
  defp get_friendship_status(nil, _other_id), do: :none
  defp get_friendship_status(_user_id, nil), do: :none

  defp get_friendship_status(user_id, other_id) do
    # user_idとother_idがUUID形式かチェック
    with {:ok, _} <- Ecto.UUID.cast(user_id),
         {:ok, _} <- Ecto.UUID.cast(other_id) do
      case Friends.get_friendship(user_id, other_id) do
        nil -> :none
        %{status: status} -> status
      end
    else
      _ -> :none
    end
  end

  defp update_players_friendship_status(socket) do
    game_state = socket.assigns.game_state
    assign(socket, :players, get_players(game_state))
  end
end
