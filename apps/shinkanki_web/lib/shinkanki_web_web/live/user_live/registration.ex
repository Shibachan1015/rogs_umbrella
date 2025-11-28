defmodule ShinkankiWebWeb.UserLive.Registration do
  @moduledoc """
  新規登録画面
  """
  use ShinkankiWebWeb, :live_view

  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{})

    socket =
      socket
      |> assign(:current_scope, nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={assigns[:current_user]}>
      <div class="auth-container">
        <div class="auth-card">
          <div class="auth-header">
            <h1 class="auth-title">神環記</h1>
            <p class="auth-subtitle">新規登録</p>
          </div>

          <.form
            for={@form}
            id="registration-form"
            phx-submit="save"
            phx-change="validate"
            class="auth-form"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="メールアドレス"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="パスワード"
              autocomplete="new-password"
              required
            />

            <div class="auth-actions">
              <button type="submit" class="auth-submit-btn" phx-disable-with="登録中...">
                アカウントを作成
              </button>
            </div>
          </.form>

          <div class="auth-footer">
            <p>
              既にアカウントをお持ちの方は
              <.link navigate={~p"/users/log-in"} class="auth-link">
                ログイン
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # パスワードも含めて登録
    case register_user_with_password(user_params) do
      {:ok, user} ->
        # 登録後すぐにログインしてプロフィールページに遷移
        # トークンを生成して自動ログインエンドポイントにリダイレクト
        token = Accounts.generate_user_session_token(user)
        # Base64エンコード（URL-safe、UTF-8エラーを防ぐ）
        encoded_token = Base.url_encode64(token, padding: false)

        {:noreply,
         socket
         |> put_flash(:info, "アカウントを作成しました。プロフィールを設定してください。")
         |> redirect(
           external:
             "/users/auto-login?token=#{encoded_token}&redirect=#{URI.encode("/profile")}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  # パスワード付きでユーザー登録
  defp register_user_with_password(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> User.password_changeset(attrs)
    |> RogsIdentity.Repo.insert()
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
