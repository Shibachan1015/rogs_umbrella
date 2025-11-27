defmodule ShinkankiWebWeb.LobbyLive do
  @moduledoc """
  ロビー画面 - ルーム一覧表示・作成・参加
  rogs_comm のルームをマスターデータとして使用
  """
  use ShinkankiWebWeb, :live_view

  alias RogsComm.Rooms
  alias RogsComm.Rooms.Room

  @impl true
  def mount(_params, _session, socket) do
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
      # ルーム一覧を取得（公開ルームのみ）
      rooms = Rooms.list_rooms(include_private: false)

      # ルーム作成フォーム
      changeset = Room.changeset(%Room{}, %{})

      # 開発環境用のゲストユーザー
      effective_user =
        current_user ||
          %{id: Ecto.UUID.generate(), email: "dev@guest.local"}

      socket =
        socket
        |> assign(:current_user, effective_user)
        |> assign(:current_scope, nil)
        |> assign(:rooms, rooms)
        |> assign(:form, to_form(changeset))
        |> assign(:show_create_form, false)

      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="lobby-container min-h-screen">
        <!-- Header -->
        <header class="lobby-header">
          <div class="lobby-header-content">
            <h1 class="lobby-title">神環記 ロビー</h1>
            <p class="lobby-subtitle">ルームを選んでゲームに参加しましょう</p>
          </div>

          <!-- ログインユーザー表示 -->
          <div class="lobby-user-status">
            <div class="user-logged-in">
              <span class="user-icon">👤</span>
              <span class="user-email">{@current_user.email}</span>
            </div>
          </div>
        </header>

        <!-- メインコンテンツ -->
        <main class="lobby-main">
          <!-- ルーム作成ボタン -->
          <div class="lobby-actions">
            <button
              type="button"
              class="create-room-btn"
              phx-click="toggle_create_form"
            >
              <span class="btn-icon">＋</span>
              <span>新しいルームを作成</span>
            </button>
          </div>

          <!-- ルーム作成フォーム -->
          <%= if @show_create_form do %>
            <div class="create-room-form-container">
              <.form for={@form} id="create-room-form" phx-submit="create_room" phx-change="validate">
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
                  <.input field={@form[:max_participants]} type="select" options={[
                    {"2人", 2},
                    {"3人", 3},
                    {"4人", 4}
                  ]} />
                </div>

                <div class="form-actions">
                  <button type="submit" class="submit-btn">作成する</button>
                </div>
              </.form>
            </div>
          <% end %>

          <!-- ルーム一覧 -->
          <div class="rooms-section">
            <h2 class="section-title">公開ルーム</h2>

            <%= if @rooms == [] do %>
              <div class="empty-rooms">
                <p>まだルームがありません</p>
                <p class="empty-rooms-hint">新しいルームを作成して、仲間を待ちましょう</p>
              </div>
            <% else %>
              <div class="rooms-grid">
                <%= for room <- @rooms do %>
                  <.room_card room={room} />
                <% end %>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # ルームカードコンポーネント
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
        <.link navigate={~p"/room/#{@room.slug}"} class="join-room-btn">
          参加する
        </.link>
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
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset =
      %Room{}
      |> Room.changeset(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    case Rooms.create_room(room_params) do
      {:ok, room} ->
        # 作成したルームに遷移
        {:noreply,
         socket
         |> put_flash(:info, "ルーム「#{room.name}」を作成しました")
         |> push_navigate(to: ~p"/room/#{room.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
