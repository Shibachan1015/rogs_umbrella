defmodule ShinkankiWebWeb.UserLive.Profile do
  use ShinkankiWebWeb, :live_view

  alias RogsIdentity.Accounts
  alias RogsIdentity.Friends

  @impl true
  def mount(_params, session, socket) do
    user = get_user_from_session(session)

    if user do
      changeset = Accounts.change_user_profile(user)

      {:ok,
       socket
       |> assign(:current_scope, nil)
       |> assign(:current_user, user)
       |> assign(:form, to_form(changeset))
       |> assign(:stats, Accounts.get_user_stats(user))
       |> assign(:pending_count, Friends.count_pending_requests(user.id))
       |> assign(:saved, false)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <div class="profile-container">
        <div class="profile-card">
          <h1 class="profile-title">🎮 プロフィール編集</h1>

          <.form for={@form} id="profile-form" phx-submit="save" phx-change="validate" class="profile-form">
            <%!-- アバター選択 --%>
            <div class="avatar-section">
              <div class="avatar-preview">
                <span class="avatar-emoji">{@form[:avatar].value || "🎮"}</span>
              </div>
              <div class="avatar-picker">
                <label class="form-label">アバター（絵文字）</label>
                <div class="emoji-grid">
                  <button
                    :for={emoji <- ~w(🎮 🎲 🎯 🎪 🌲 🌸 🌙 ⭐ 🔮 🎭 🦊 🐉 👤 👻 🤖 🎨)}
                    type="button"
                    class={["emoji-btn", @form[:avatar].value == emoji && "selected"]}
                    phx-click="select_avatar"
                    phx-value-avatar={emoji}
                  >
                    {emoji}
                  </button>
                </div>
                <input type="hidden" name={@form[:avatar].name} value={@form[:avatar].value || "🎮"} />
              </div>
            </div>

            <%!-- 表示名 --%>
            <div class="form-group">
              <label class="form-label" for="profile_name">表示名</label>
              <input
                type="text"
                id="profile_name"
                name={@form[:name].name}
                value={@form[:name].value}
                placeholder="ニックネームを入力"
                class="profile-input"
                maxlength="30"
              />
              <p class="form-hint">1〜30文字（ゲーム中やロビーで表示されます）</p>
              <%= if @form[:name].errors != [] do %>
                <p class="form-error">
                  <%= Enum.map(@form[:name].errors, fn {msg, _opts} -> msg end) |> Enum.join(", ") %>
                </p>
              <% end %>
            </div>

            <%!-- 自己紹介 --%>
            <div class="form-group">
              <label class="form-label" for="profile_bio">自己紹介</label>
              <textarea
                id="profile_bio"
                name={@form[:bio].name}
                placeholder="自己紹介を入力（任意）"
                class="profile-textarea"
                maxlength="200"
                rows="3"
              ><%= @form[:bio].value %></textarea>
              <p class="form-hint">200文字以内</p>
              <%= if @form[:bio].errors != [] do %>
                <p class="form-error">
                  <%= Enum.map(@form[:bio].errors, fn {msg, _opts} -> msg end) |> Enum.join(", ") %>
                </p>
              <% end %>
            </div>

            <%!-- 保存ボタン --%>
            <div class="form-actions">
              <button type="submit" class="save-btn">
                💾 保存する
              </button>
              <%= if @saved do %>
                <span class="save-success">✓ 保存しました！</span>
              <% end %>
            </div>
          </.form>

          <%!-- 統計情報 --%>
          <div class="stats-section">
            <h2 class="stats-title">📊 ゲーム統計</h2>
            <div class="stats-grid">
              <div class="stat-item">
                <span class="stat-value">{@stats.games_played}</span>
                <span class="stat-label">プレイ回数</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{@stats.games_won}</span>
                <span class="stat-label">勝利回数</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{@stats.win_rate}%</span>
                <span class="stat-label">勝率</span>
              </div>
            </div>
          </div>

          <%!-- フレンドリンク --%>
          <div class="friends-link-section">
            <.link navigate={~p"/friends"} class="friends-link-btn">
              👥 フレンドリスト
              <%= if @pending_count > 0 do %>
                <span class="friends-badge">{@pending_count}</span>
              <% end %>
            </.link>
          </div>

          <%!-- ロビーに戻る --%>
          <div class="back-link">
            <.link navigate={~p"/lobby"} class="back-btn">
              ← ロビーに戻る
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("select_avatar", %{"avatar" => avatar}, socket) do
    params = %{
      "name" => socket.assigns.form[:name].value,
      "avatar" => avatar,
      "bio" => socket.assigns.form[:bio].value
    }

    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(params)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, params) do
      {:ok, user} ->
        changeset = Accounts.change_user_profile(user)

        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:form, to_form(changeset))
         |> assign(:saved, true)
         |> put_flash(:info, "プロフィールを更新しました")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "プロフィールの更新に失敗しました")}
    end
  end
end
