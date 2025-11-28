defmodule ShinkankiWebWeb.UserLive.Login do
  @moduledoc """
  ログイン画面
  """
  use ShinkankiWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email, "password" => ""}, as: "user")

    socket =
      socket
      |> assign(:current_scope, nil)
      |> assign(:form, form)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={assigns[:current_user]}>
      <div class="auth-container">
        <div class="auth-card">
          <div class="auth-header">
            <h1 class="auth-title">神環記</h1>
            <p class="auth-subtitle">ログイン</p>
          </div>

          <.form
            for={@form}
            id="login-form"
            action={~p"/users/log-in"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
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
              autocomplete="current-password"
              required
            />

            <div class="auth-actions">
              <button type="submit" class="auth-submit-btn" name={@form[:remember_me].name} value="true">
                ログイン
              </button>
            </div>
          </.form>

          <div class="auth-footer">
            <p>
              アカウントをお持ちでない方は
              <.link navigate={~p"/users/register"} class="auth-link">
                新規登録
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
