defmodule ShinkankiWebWeb.UserLive.Friends do
  use ShinkankiWebWeb, :live_view

  alias RogsIdentity.Accounts
  alias RogsIdentity.Friends

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user do
      {:ok,
       socket
       |> assign(:current_scope, nil)
       |> assign(:current_user, user)
       |> assign(:tab, :friends)
       |> load_friends_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "ログインが必要です")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  defp get_user_from_session(session) do
    token = session["user_token"]
    if token, do: get_user_from_token(token), else: nil
  end

  defp get_user_from_token(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _inserted_at} -> user
      _ -> nil
    end
  end

  defp load_friends_data(socket) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:friends, Friends.list_friends(user_id))
    |> assign(:pending_requests, Friends.list_pending_requests(user_id))
    |> assign(:sent_requests, Friends.list_sent_requests(user_id))
    |> assign(:recent_players, Friends.list_recent_players(user_id, limit: 10))
    |> assign(:friends_count, Friends.count_friends(user_id))
    |> assign(:pending_count, Friends.count_pending_requests(user_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="friends-container">
        <div class="friends-card">
          <header class="friends-header">
            <h1 class="friends-title">👥 フレンド</h1>
            <.link navigate={~p"/profile"} class="back-link">
              ← プロフィールに戻る
            </.link>
          </header>

          <%!-- タブ --%>
          <div class="friends-tabs">
            <button
              type="button"
              class={["tab-btn", @tab == :friends && "tab-btn--active"]}
              phx-click="switch_tab"
              phx-value-tab="friends"
            >
              フレンド ({@friends_count})
            </button>
            <button
              type="button"
              class={["tab-btn", @tab == :requests && "tab-btn--active"]}
              phx-click="switch_tab"
              phx-value-tab="requests"
            >
              申請
              <%= if @pending_count > 0 do %>
                <span class="badge">{@pending_count}</span>
              <% end %>
            </button>
            <button
              type="button"
              class={["tab-btn", @tab == :recent && "tab-btn--active"]}
              phx-click="switch_tab"
              phx-value-tab="recent"
            >
              最近遊んだ人
            </button>
          </div>

          <%!-- タブコンテンツ --%>
          <div class="tab-content">
            <%= case @tab do %>
              <% :friends -> %>
                <.friends_list friends={@friends} />

              <% :requests -> %>
                <.requests_panel
                  pending_requests={@pending_requests}
                  sent_requests={@sent_requests}
                />

              <% :recent -> %>
                <.recent_players_list players={@recent_players} current_user_id={@current_user.id} />
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # フレンドリストコンポーネント
  attr :friends, :list, required: true

  defp friends_list(assigns) do
    ~H"""
    <div class="friends-list">
      <%= if @friends == [] do %>
        <div class="empty-state">
          <p class="empty-icon">👤</p>
          <p class="empty-text">まだフレンドがいません</p>
          <p class="empty-hint">ゲームで一緒に遊んだ人にフレンド申請してみましょう</p>
        </div>
      <% else %>
        <%= for friend <- @friends do %>
          <div class="friend-item">
            <div class="friend-avatar">{friend.avatar || "🎮"}</div>
            <div class="friend-info">
              <span class="friend-name">{friend.name || friend.email}</span>
              <span class="friend-stats">
                🎮 {friend.games_played}回プレイ / 🏆 {friend.games_won}勝
              </span>
            </div>
            <div class="friend-actions">
              <button
                type="button"
                class="remove-btn"
                phx-click="remove_friend"
                phx-value-id={friend.friendship_id}
                data-confirm="#{friend.name || friend.email} をフレンドから削除しますか？"
              >
                削除
              </button>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # 申請パネルコンポーネント
  attr :pending_requests, :list, required: true
  attr :sent_requests, :list, required: true

  defp requests_panel(assigns) do
    ~H"""
    <div class="requests-panel">
      <%!-- 受信した申請 --%>
      <div class="requests-section">
        <h3 class="section-title">📥 受信した申請</h3>
        <%= if @pending_requests == [] do %>
          <p class="empty-hint">申請はありません</p>
        <% else %>
          <%= for request <- @pending_requests do %>
            <div class="request-item">
              <div class="request-avatar">{request.avatar || "🎮"}</div>
              <div class="request-info">
                <span class="request-name">{request.name || request.email}</span>
                <span class="request-time">{format_date(request.requested_at)}</span>
              </div>
              <div class="request-actions">
                <button
                  type="button"
                  class="accept-btn"
                  phx-click="accept_request"
                  phx-value-id={request.id}
                >
                  承認
                </button>
                <button
                  type="button"
                  class="reject-btn"
                  phx-click="reject_request"
                  phx-value-id={request.id}
                >
                  拒否
                </button>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <%!-- 送信した申請 --%>
      <div class="requests-section">
        <h3 class="section-title">📤 送信した申請</h3>
        <%= if @sent_requests == [] do %>
          <p class="empty-hint">送信した申請はありません</p>
        <% else %>
          <%= for request <- @sent_requests do %>
            <div class="request-item sent">
              <div class="request-avatar">{request.avatar || "🎮"}</div>
              <div class="request-info">
                <span class="request-name">{request.name || request.email}</span>
                <span class="request-time">{format_date(request.sent_at)} に送信</span>
              </div>
              <div class="request-status">
                ⏳ 承認待ち
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # 最近遊んだ人リストコンポーネント
  attr :players, :list, required: true
  attr :current_user_id, :string, required: true

  defp recent_players_list(assigns) do
    ~H"""
    <div class="recent-players-list">
      <%= if @players == [] do %>
        <div class="empty-state">
          <p class="empty-icon">🎲</p>
          <p class="empty-text">まだ誰とも遊んでいません</p>
          <p class="empty-hint">ゲームに参加すると、一緒に遊んだ人がここに表示されます</p>
        </div>
      <% else %>
        <%= for player <- @players do %>
          <div class="player-item">
            <div class="player-avatar">{player.avatar || "🎮"}</div>
            <div class="player-info">
              <span class="player-name">{player.name || player.email}</span>
              <span class="player-stats">
                🎮 {player.play_count}回一緒にプレイ
              </span>
            </div>
            <div class="player-actions">
              <button
                type="button"
                class="add-friend-btn"
                phx-click="send_request"
                phx-value-id={player.id}
              >
                + フレンド申請
              </button>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # イベントハンドラ
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("accept_request", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Friends.accept_friend_request(id, user_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "フレンド申請を承認しました")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "承認できませんでした")}
    end
  end

  @impl true
  def handle_event("reject_request", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Friends.reject_friend_request(id, user_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "フレンド申請を拒否しました")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "拒否できませんでした")}
    end
  end

  @impl true
  def handle_event("remove_friend", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Friends.remove_friend(user_id, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "フレンドを削除しました")
         |> load_friends_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "削除できませんでした")}
    end
  end

  @impl true
  def handle_event("send_request", %{"id" => addressee_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Friends.send_friend_request(user_id, addressee_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "フレンド申請を送信しました")
         |> load_friends_data()}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :error, "すでに申請済みです")}

      {:error, :already_friends} ->
        {:noreply, put_flash(socket, :error, "すでにフレンドです")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "申請できませんでした")}
    end
  end

  # ヘルパー
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y/%m/%d")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y/%m/%d")
  defp format_date(_), do: ""
end

