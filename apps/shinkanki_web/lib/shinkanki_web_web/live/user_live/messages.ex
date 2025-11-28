defmodule ShinkankiWebWeb.UserLive.Messages do
  use ShinkankiWebWeb, :live_view

  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.User
  alias RogsIdentity.Messages

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user do
      # DM通知を購読
      if connected?(socket) do
        Messages.subscribe_dm(user.id)
      end

      {:ok,
       socket
       |> assign(:current_scope, nil)
       |> assign(:current_user, user)
       |> assign(:conversations, Messages.list_conversations(user.id))
       |> assign(:selected_user, nil)
       |> assign(:messages, [])
       |> assign(:message_form, to_form(%{"content" => ""}, as: :message))
       |> assign(:unread_count, Messages.count_all_unread(user.id))}
    else
      {:ok,
       socket
       |> put_flash(:error, "ログインが必要です")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _uri, socket) do
    current_user = socket.assigns.current_user

    case Accounts.get_user(user_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "ユーザーが見つかりません")}

      selected_user ->
        # メッセージを既読に
        Messages.mark_as_read(current_user.id, user_id)

        {:noreply,
         socket
         |> assign(:selected_user, selected_user)
         |> assign(:messages, Messages.list_conversation(current_user.id, user_id))
         |> assign(:conversations, Messages.list_conversations(current_user.id))
         |> assign(:unread_count, Messages.count_all_unread(current_user.id))}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="messages-container">
        <div class="messages-layout">
          <%!-- 会話リスト（左サイドバー） --%>
          <aside class="conversations-sidebar">
            <header class="sidebar-header">
              <h2 class="sidebar-title">💬 メッセージ</h2>
              <.link navigate={~p"/friends"} class="back-link-small">
                ← フレンドに戻る
              </.link>
            </header>

            <div class="conversations-list">
              <%= if @conversations == [] do %>
                <div class="empty-conversations">
                  <p>メッセージはまだありません</p>
                  <p class="hint">フレンドにメッセージを送ってみましょう</p>
                </div>
              <% else %>
                <%= for conv <- @conversations do %>
                  <.link
                    patch={~p"/messages/#{conv.user_id}"}
                    class={["conversation-item", @selected_user && @selected_user.id == conv.user_id && "selected"]}
                  >
                    <span class="conv-avatar">{conv.avatar || "🎮"}</span>
                    <div class="conv-info">
                      <span class="conv-name">{conv.name}</span>
                      <span class="conv-preview">{truncate(conv.last_content, 30)}</span>
                    </div>
                    <%= if conv.unread_count > 0 do %>
                      <span class="unread-badge">{conv.unread_count}</span>
                    <% end %>
                  </.link>
                <% end %>
              <% end %>
            </div>
          </aside>

          <%!-- メッセージエリア（メイン） --%>
          <main class="message-area">
            <%= if @selected_user do %>
              <header class="message-header">
                <span class="user-avatar">{User.avatar(@selected_user)}</span>
                <span class="user-name">{User.display_name(@selected_user)}</span>
              </header>

              <div id="messages-list" class="messages-list" phx-hook="MessageScroll">
                <%= for msg <- @messages do %>
                  <div class={["message", msg.sender_id == @current_user.id && "message--sent"]}>
                    <div class="message-content">{msg.content}</div>
                    <div class="message-time">{format_time(msg.inserted_at)}</div>
                  </div>
                <% end %>
              </div>

              <.form for={@message_form} id="message-form" phx-submit="send_message" class="message-form">
                <input
                  type="text"
                  name="message[content]"
                  value={@message_form[:content].value}
                  placeholder="メッセージを入力..."
                  class="message-input"
                  autocomplete="off"
                />
                <button type="submit" class="send-btn">送信</button>
              </.form>
            <% else %>
              <div class="no-conversation-selected">
                <p class="empty-icon">💬</p>
                <p>左のリストから会話を選択してください</p>
                <p class="hint">または、フレンドリストから新しい会話を始めましょう</p>
              </div>
            <% end %>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content)
    current_user = socket.assigns.current_user
    selected_user = socket.assigns.selected_user

    if content != "" and selected_user do
      case Messages.send_message(current_user.id, selected_user.id, content) do
        {:ok, message} ->
          {:noreply,
           socket
           |> assign(:messages, socket.assigns.messages ++ [message])
           |> assign(:message_form, to_form(%{"content" => ""}, as: :message))}

        {:error, :not_friends} ->
          {:noreply, put_flash(socket, :error, "フレンドでないとメッセージを送れません")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "メッセージの送信に失敗しました")}
      end
    else
      {:noreply, socket}
    end
  end

  # 新しいメッセージを受信
  @impl true
  def handle_info({:new_message, message}, socket) do
    current_user = socket.assigns.current_user
    selected_user = socket.assigns.selected_user

    socket =
      if selected_user && message.sender_id == selected_user.id do
        # 現在の会話なら既読にしてメッセージを追加
        Messages.mark_as_read(current_user.id, message.sender_id)

        socket
        |> assign(:messages, socket.assigns.messages ++ [message])
      else
        # 別の会話ならリストを更新
        socket
        |> assign(:conversations, Messages.list_conversations(current_user.id))
        |> assign(:unread_count, Messages.count_all_unread(current_user.id))
      end

    {:noreply, socket}
  end

  # ヘルパー
  defp format_time(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_time(_), do: ""

  defp truncate(nil, _), do: ""

  defp truncate(string, max_length) when is_binary(string) do
    if String.length(string) > max_length do
      String.slice(string, 0, max_length) <> "..."
    else
      string
    end
  end
end
