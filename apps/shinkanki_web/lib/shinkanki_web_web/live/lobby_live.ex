defmodule ShinkankiWebWeb.LobbyLive do
  @moduledoc """
  ロビー画面 - ルーム一覧表示・作成・参加
  rogs_comm のルームをマスターデータとして使用
  """
  use ShinkankiWebWeb, :live_view

  alias RogsComm.Rooms
  alias RogsComm.Rooms.Room
  alias RogsIdentity.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    # ログイン状態を確認（on_mountで設定されるか、ここで再取得）
    current_user = socket.assigns[:current_user]

    # current_userがnilの場合、開発バイパスをチェック
    current_user =
      if is_nil(current_user) && Application.get_env(:rogs_identity, :dev_bypass_auth, false) do
        get_or_create_dev_user()
      else
        current_user
      end

    # ルーム作成フォーム
    changeset = Room.changeset(%Room{}, %{})

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:logged_in, current_user != nil)
      |> assign(:current_scope, nil)
      |> assign(:search, "")
      |> assign(:filter_has_space, false)
      |> assign(:form, to_form(changeset))
      |> assign(:show_create_form, false)
      |> assign(:rooms, nil)
      |> assign(:loading_rooms, true)
      |> assign(:invite_code, "")
      |> assign(:quick_matching, false)

    # 非同期でルーム一覧を読み込み（初期表示高速化）
    # category: "game" でフィルタ（神議りの間のチャンネルは除外）
    socket =
      if connected?(socket) do
        start_async(socket, :load_rooms, fn ->
          Rooms.list_rooms(category: "game", include_private: false, limit: 50)
        end)
      else
        # SSR時は同期で読み込み（SEO対策）
        load_rooms(socket)
        |> assign(:loading_rooms, false)
      end

    {:ok, socket}
  end

  # 非同期読み込み完了
  @impl true
  def handle_async(:load_rooms, {:ok, rooms}, socket) do
    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:loading_rooms, false)}
  end

  def handle_async(:load_rooms, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:rooms, [])
     |> assign(:loading_rooms, false)
     |> put_flash(:error, "ルームの読み込みに失敗しました")}
  end

  defp get_or_create_dev_user do
    alias RogsIdentity.Accounts
    email = "dev@example.com"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{email: email, password: "devpassword123"})
        user

      user ->
        user
    end
  end

  # ルーム一覧を読み込み（ゲームルームのみ）
  defp load_rooms(socket) do
    rooms =
      Rooms.list_rooms(
        category: "game",
        include_private: false,
        search: socket.assigns.search,
        has_space: socket.assigns.filter_has_space,
        limit: 50
      )

    assign(socket, :rooms, rooms)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="lobby-container min-h-screen">
        <!-- Header -->
        <header class="lobby-header">
          <div class="lobby-header-content">
            <.link navigate={~p"/"} class="lobby-logo">神環記</.link>
            <nav class="lobby-nav">
              <a href="/rulebook" class="nav-link">ルールブック</a>
              <a href="/story" class="nav-link">物語</a>
              <div class="nav-dropdown" id="card-list-dropdown" phx-hook="NavDropdown">
                <span class="nav-link dropdown-toggle">カード一覧</span>
                <div class="dropdown-menu">
                  <a href="/cards/talent">才能カード</a>
                  <a href="/cards/cocreation">共創カード</a>
                  <a href="/cards/action">アクションカード</a>
                  <a href="/cards/hitoyo">人代カード</a>
                  <a href="/cards/migaki">磨きカード</a>
                  <a href="/kuukan">空環</a>
                </div>
              </div>
              <a href="/kamihakari" class="nav-link">神議りの間</a>
            </nav>
          </div>
          
    <!-- ログインユーザー表示 -->
          <%= if @logged_in do %>
            <div class="lobby-user-status">
              <div class="user-logged-in">
                <span class="user-avatar">{User.avatar(@current_user)}</span>
                <span class="user-name">{User.display_name(@current_user)}</span>
                <.link navigate={~p"/profile"} class="profile-link" title="プロフィール編集">
                  ⚙️
                </.link>
                <.link href={~p"/users/log-out"} method="delete" class="logout-btn">
                  ログアウト
                </.link>
              </div>
            </div>
          <% end %>
        </header>
        
    <!-- メインコンテンツ -->
        <main class="lobby-main">
          <!-- アクションボタン（ログイン時のみ） -->
          <%= if @logged_in do %>
            <div class="lobby-actions">
              <button
                type="button"
                class="quick-match-btn"
                phx-click="quick_match"
                disabled={@quick_matching}
              >
                <span class="btn-icon">⚡</span>
                <span><%= if @quick_matching, do: "マッチング中...", else: "クイックマッチ" %></span>
              </button>

              <div class="invite-code-form">
                <form phx-submit="join_by_code">
                  <input
                    type="text"
                    name="code"
                    value={@invite_code}
                    placeholder="招待コード"
                    maxlength="6"
                    class="invite-code-input"
                    phx-change="update_invite_code"
                  />
                  <button type="submit" class="invite-code-btn">参加</button>
                </form>
              </div>

              <button
                type="button"
                class="create-room-btn"
                phx-click="toggle_create_form"
              >
                <span class="btn-icon">＋</span>
                <span>新しいルームを作成</span>
              </button>
            </div>
          <% else %>
            <div class="lobby-login-prompt">
              <p>ルームに参加するにはログインが必要です</p>
              <div class="login-prompt-actions">
                <a
                  href={~p"/auth/google?return_to=/lobby"}
                  class="auth-btn oauth-btn oauth-google login-btn-large"
                >
                  <svg class="oauth-icon-svg" viewBox="0 0 24 24">
                    <path
                      fill="#4285F4"
                      d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                    /><path
                      fill="#34A853"
                      d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                    /><path
                      fill="#FBBC05"
                      d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                    /><path
                      fill="#EA4335"
                      d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                    />
                  </svg>
                  Googleでログイン
                </a>
                <a
                  href={~p"/auth/github?return_to=/lobby"}
                  class="auth-btn oauth-btn oauth-github login-btn-large"
                >
                  <svg class="oauth-icon-svg" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
                  </svg>
                  GitHubでログイン
                </a>
              </div>
            </div>
          <% end %>
          
    <!-- ルーム作成フォーム -->
          <%= if @show_create_form do %>
            <div class="create-room-form-container">
              <.form
                for={@form}
                id="create-room-form"
                phx-submit="create_room"
                phx-change="validate"
                data-1p-ignore
              >
                <div class="form-header">
                  <h3>新しいルームを作成</h3>
                  <button type="button" class="close-btn" phx-click="toggle_create_form">×</button>
                </div>

                <div class="form-field">
                  <label for="room_name">ルーム名</label>
                  <.input field={@form[:name]} type="text" placeholder="例: 森の守護者たち" />
                </div>

                <div class="form-field">
                  <label for="room_topic">トピック（任意）</label>
                  <.input field={@form[:topic]} type="text" placeholder="例: 初心者歓迎！" />
                </div>

                <div class="form-field">
                  <label for="room_max_participants">最大参加人数</label>
                  <.input
                    field={@form[:max_participants]}
                    type="select"
                    options={[
                      {"2人", 2},
                      {"3人", 3},
                      {"4人", 4}
                    ]}
                  />
                </div>

                <div class="form-actions">
                  <button type="submit" class="submit-btn">作成する</button>
                </div>
              </.form>
            </div>
          <% end %>
          
    <!-- 検索・フィルター -->
          <div class="search-filter-section">
            <div class="search-box">
              <form phx-change="search" phx-submit="search">
                <input
                  type="text"
                  name="query"
                  value={@search}
                  placeholder="ルーム名・トピックで検索..."
                  class="search-input"
                  phx-debounce="300"
                />
              </form>
            </div>

            <div class="filter-options">
              <label class="filter-checkbox">
                <input
                  type="checkbox"
                  checked={@filter_has_space}
                  phx-click="toggle_filter_space"
                />
                <span>空きありのみ</span>
              </label>
            </div>
          </div>
          
    <!-- ルーム一覧 -->
          <div class="rooms-section">
            <div class="section-header">
              <h2 class="section-title">公開ルーム</h2>
              <span class="room-count">
                {if @loading_rooms, do: "読み込み中...", else: "#{length(@rooms || [])}件"}
              </span>
            </div>

            <%= if @loading_rooms do %>
              <div class="loading-rooms">
                <div class="loading-spinner"></div>
                <p>ルームを読み込んでいます...</p>
              </div>
            <% else %>
              <%= if @rooms == [] do %>
                <div class="empty-rooms">
                  <%= if @search != "" do %>
                    <p>「{@search}」に一致するルームが見つかりません</p>
                    <p class="empty-rooms-hint">別のキーワードで検索してみてください</p>
                  <% else %>
                    <p>まだルームがありません</p>
                    <p class="empty-rooms-hint">新しいルームを作成して、仲間を待ちましょう</p>
                  <% end %>
                </div>
              <% else %>
                <div class="rooms-grid">
                  <%= for room <- @rooms do %>
                    <.room_card room={room} logged_in={@logged_in} />
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # ルームカードコンポーネント
  attr :room, :map, required: true
  attr :logged_in, :boolean, required: true

  defp room_card(assigns) do
    ~H"""
    <div class="room-card">
      <div class="room-card-header">
        <h3 class="room-name">{@room.name}</h3>
        <%= if @room.topic do %>
          <p class="room-topic">{@room.topic}</p>
        <% end %>
      </div>

      <div class="room-card-info">
        <div class="room-participants">
          <span class="participants-icon">👥</span>
          <span>最大 {@room.max_participants}人</span>
        </div>
      </div>

      <div class="room-card-actions">
        <%= if @logged_in do %>
          <.link navigate={~p"/room/#{@room.slug}"} class="join-room-btn">
            参加する
          </.link>
        <% else %>
          <.link navigate={~p"/users/log-in"} class="join-room-btn join-room-disabled">
            ログインして参加
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  # イベントハンドラ
  @impl true
  def handle_event("toggle_create_form", _params, socket) do
    {:noreply, assign(socket, :show_create_form, !socket.assigns.show_create_form)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search, query)
      |> load_rooms()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_filter_space", _params, socket) do
    socket =
      socket
      |> assign(:filter_has_space, !socket.assigns.filter_has_space)
      |> load_rooms()

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset =
      %Room{}
      |> Room.changeset(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    host_id = socket.assigns.current_user.id

    case Rooms.create_room_with_host(room_params, host_id) do
      {:ok, room} ->
        # 作成したルームに遷移
        {:noreply,
         socket
         |> put_flash(:info, "ルーム「#{room.name}」を作成しました")
         |> push_navigate(to: ~p"/room/#{room.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "ルームの作成に失敗しました。同じ名前のルームが既に存在する可能性があります。")
         |> assign(form: to_form(changeset))}
    end
  end

  # クイックマッチ
  @impl true
  def handle_event("quick_match", _params, socket) do
    host_id = socket.assigns.current_user.id

    case Rooms.quick_match(host_id) do
      {:ok, room} ->
        {:noreply,
         socket
         |> put_flash(:info, "ルーム「#{room.name}」に参加します")
         |> push_navigate(to: ~p"/room/#{room.slug}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "マッチングに失敗しました。もう一度お試しください。")}
    end
  end

  # 招待コード入力更新
  @impl true
  def handle_event("update_invite_code", %{"code" => code}, socket) do
    {:noreply, assign(socket, :invite_code, String.upcase(code))}
  end

  # 招待コードで参加
  @impl true
  def handle_event("join_by_code", %{"code" => code}, socket) do
    code = String.trim(code)

    if code == "" do
      {:noreply, put_flash(socket, :error, "招待コードを入力してください")}
    else
      case Rooms.get_room_by_invite_code(code) do
        nil ->
          {:noreply,
           socket
           |> put_flash(:error, "招待コード「#{code}」のルームが見つかりません")
           |> assign(:invite_code, "")}

        room ->
          {:noreply,
           socket
           |> put_flash(:info, "ルーム「#{room.name}」に参加します")
           |> push_navigate(to: ~p"/room/#{room.slug}")}
      end
    end
  end
end
