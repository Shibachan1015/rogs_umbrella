defmodule ShinkankiWebWeb.KamihakariLive do
  @moduledoc """
  神議りの間 - コミュニティフォーラム
  Discord風のチャンネル式チャット
  """
  use ShinkankiWebWeb, :live_view

  alias RogsComm.Rooms
  alias RogsComm.Messages

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # チャンネル一覧を取得
    channels = Rooms.list_rooms(category: "kamihakari")

    # 初期チャンネル（パラメータまたはデフォルト）
    initial_slug = params["channel"] || "danwa"
    current_channel = Enum.find(channels, List.first(channels), &(&1.slug == initial_slug))

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:logged_in, current_user != nil)
      |> assign(:current_scope, nil)
      |> assign(:channels, channels)
      |> assign(:current_channel, current_channel)
      |> assign(:messages, [])
      |> assign(:loading_messages, true)
      |> assign(:message_input, "")

    # メッセージを非同期で読み込み
    socket =
      if connected?(socket) && current_channel do
        if current_user do
          # PubSubでリアルタイム更新を購読
          Phoenix.PubSub.subscribe(RogsComm.PubSub, "room:#{current_channel.id}")
        end

        start_async(socket, :load_messages, fn ->
          Messages.list_messages(current_channel.id, limit: 50)
        end)
      else
        assign(socket, :loading_messages, false)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"channel" => slug}, _uri, socket) do
    channels = socket.assigns.channels
    current_channel = Enum.find(channels, &(&1.slug == slug))

    if current_channel do
      # 以前のチャンネルの購読を解除
      if socket.assigns.current_channel do
        Phoenix.PubSub.unsubscribe(RogsComm.PubSub, "room:#{socket.assigns.current_channel.id}")
      end

      # 新しいチャンネルを購読
      if socket.assigns.current_user do
        Phoenix.PubSub.subscribe(RogsComm.PubSub, "room:#{current_channel.id}")
      end

      socket =
        socket
        |> assign(:current_channel, current_channel)
        |> assign(:loading_messages, true)
        |> start_async(:load_messages, fn ->
          Messages.list_messages(current_channel.id, limit: 50)
        end)

      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/kamihakari")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:load_messages, {:ok, messages}, socket) do
    {:noreply,
     socket
     |> assign(:messages, Enum.reverse(messages))
     |> assign(:loading_messages, false)}
  end

  def handle_async(:load_messages, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:loading_messages, false)
     |> put_flash(:error, "メッセージの読み込みに失敗しました")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="kamihakari-container">
        <!-- サイドバー: チャンネル一覧 -->
        <aside class="kamihakari-sidebar">
          <div class="sidebar-header">
            <h2>神議りの間</h2>
            <p class="sidebar-subtitle">意見交換フォーラム</p>
          </div>

          <nav class="channel-list">
            <%= for channel <- @channels do %>
              <.link
                patch={~p"/kamihakari/#{channel.slug}"}
                class={"channel-item #{if @current_channel && @current_channel.id == channel.id, do: "active", else: ""}"}
              >
                <span class="channel-name">{channel.name}</span>
                <span class="channel-topic">{channel.topic}</span>
              </.link>
            <% end %>
          </nav>

          <div class="sidebar-footer">
            <.link navigate={~p"/lobby"} class="back-to-lobby">
              ← ロビーに戻る
            </.link>
          </div>
        </aside>

        <!-- メイン: チャットエリア -->
        <main class="kamihakari-main">
          <%= if @current_channel do %>
            <!-- チャンネルヘッダー -->
            <header class="chat-header">
              <h3 class="chat-channel-name">{@current_channel.name}</h3>
              <p class="chat-channel-topic">{@current_channel.topic}</p>
            </header>

            <!-- メッセージ一覧 -->
            <div class="messages-container" id="messages-container" phx-hook="ScrollToBottom">
              <%= if @loading_messages do %>
                <div class="loading-messages">
                  <div class="loading-spinner"></div>
                  <p>メッセージを読み込み中...</p>
                </div>
              <% else %>
                <%= if @messages == [] do %>
                  <div class="empty-messages">
                    <p>まだメッセージがありません</p>
                    <p class="empty-hint">最初のメッセージを投稿してみましょう</p>
                  </div>
                <% else %>
                  <%= for message <- @messages do %>
                    <.message_item message={message} current_user={@current_user} />
                  <% end %>
                <% end %>
              <% end %>
            </div>

            <!-- メッセージ入力 -->
            <%= if @logged_in do %>
              <form class="message-form" phx-submit="send_message">
                <input
                  type="text"
                  name="content"
                  value={@message_input}
                  placeholder={"#{@current_channel.name} にメッセージを送信"}
                  class="message-input"
                  autocomplete="off"
                  phx-debounce="100"
                />
                <button type="submit" class="send-btn">送信</button>
              </form>
            <% else %>
              <div class="login-prompt">
                <p>メッセージを送信するには</p>
                <.link href={~p"/auth/google?return_to=/kamihakari/#{@current_channel.slug}"} class="login-link">
                  ログイン
                </.link>
                <span>してください</span>
              </div>
            <% end %>
          <% else %>
            <div class="no-channel-selected">
              <p>チャンネルを選択してください</p>
            </div>
          <% end %>
        </main>
      </div>
    </Layouts.app>
    """
  end

  # メッセージアイテムコンポーネント
  attr :message, :map, required: true
  attr :current_user, :map, default: nil

  defp message_item(assigns) do
    ~H"""
    <div class="message-item">
      <div class="message-avatar">
        <%= if @message.user_email do %>
          <span class="avatar-initial">{String.first(@message.user_email) |> String.upcase()}</span>
        <% else %>
          <span class="avatar-initial">?</span>
        <% end %>
      </div>
      <div class="message-content">
        <div class="message-header">
          <span class="message-author">{@message.user_email || "匿名"}</span>
          <span class="message-time">{format_time(@message.inserted_at)}</span>
        </div>
        <div class="message-body">
          {@message.content}
        </div>
      </div>
    </div>
    """
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%m/%d %H:%M")
  end

  @max_message_length 5000

  # イベントハンドラ
  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    content = String.trim(content)
    content_length = String.length(content)

    cond do
      content == "" ->
        {:noreply, socket}

      content_length > @max_message_length ->
        {:noreply, put_flash(socket, :error, "メッセージは#{@max_message_length}文字以内にしてください（現在#{content_length}文字）")}

      is_nil(socket.assigns.current_user) or is_nil(socket.assigns.current_channel) ->
        {:noreply, socket}

      true ->
        user_id = socket.assigns.current_user.id
        rate_key = "chat:#{user_id}"

        # レート制限チェック
        case ShinkankiWeb.RateLimiter.check_rate(rate_key, :chat_message) do
          {:deny, retry_after} ->
            seconds = div(retry_after, 1000) + 1
            {:noreply, put_flash(socket, :error, "送信が速すぎます。#{seconds}秒後に再試行してください")}

          {:allow, _remaining} ->
            attrs = %{
              content: content,
              room_id: socket.assigns.current_channel.id,
              user_id: user_id,
              user_email: socket.assigns.current_user.email
            }

            case Messages.create_message(attrs) do
              {:ok, message} ->
                # PubSubでブロードキャスト
                Phoenix.PubSub.broadcast(
                  RogsComm.PubSub,
                  "room:#{socket.assigns.current_channel.id}",
                  {:new_message, message}
                )

                {:noreply, assign(socket, :message_input, "")}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "メッセージの送信に失敗しました")}
            end
        end
    end
  end

  # PubSubからのメッセージ受信
  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = socket.assigns.messages ++ [message]
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
