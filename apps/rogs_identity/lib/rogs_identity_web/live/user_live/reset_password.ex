defmodule RogsIdentityWeb.UserLive.ResetPassword do
  use RogsIdentityWeb, :live_view

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="auth-card stack" style="max-width: 420px;">
        <div class="text-center">
          <h1 class="auth-title">Reset your password</h1>
          <p class="auth-subtitle">Enter and confirm your new credentials.</p>
        </div>

        <.form
          :let={f}
          for={@form}
          id="reset_password_form"
          phx-change="validate"
          phx-submit="reset_password"
        >
          <.input
            field={f[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={f[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
            required
          />

          <.button variant="primary" phx-disable-with="Resetting...">
            Reset password
          </.button>
        </.form>

        <div class="auth-helper">
          <.link navigate={~p"/users/log-in"} class="link-muted">
            Back to log in
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_password_reset_token(token) do
      changeset = Accounts.change_user_password(user)

      {:ok,
       socket
       |> assign(:token, token)
       |> assign(:user, user)
       |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Reset link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.token, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :invalid_token} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid or expired reset token.")
         |> push_navigate(to: ~p"/users/forgot-password")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
