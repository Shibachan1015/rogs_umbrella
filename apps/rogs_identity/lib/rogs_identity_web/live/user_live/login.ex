defmodule RogsIdentityWeb.UserLive.Login do
  use RogsIdentityWeb, :live_view

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mdc-card" style="max-width: 400px; margin: 48px auto;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="font-size: 24px; font-weight: 500; margin: 0 0 8px 0; color: var(--md-text-primary);">
            Log in
          </h1>
          <p style="font-size: 14px; color: var(--md-text-secondary); margin: 0;">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account? <.link
                navigate={~p"/users/register"}
                style="color: var(--md-primary); text-decoration: none; font-weight: 500;"
                phx-no-format
              >Sign up</.link> for an account now.
            <% end %>
          </p>
        </div>

        <div
          :if={local_mail_adapter?()}
          class="mdc-card"
          style="background-color: #e3f2fd; padding: 16px; margin-bottom: 24px; border-radius: 4px;"
        >
          <div style="display: flex; align-items: start; gap: 12px;">
            <span class="material-icons" style="color: #1976d2; font-size: 24px;">info</span>
            <div style="flex: 1;">
              <p style="margin: 0 0 4px 0; font-size: 14px; color: #1565c0;">
                You are running the local mail adapter.
              </p>
              <p style="margin: 0; font-size: 14px; color: #1565c0;">
                To see sent emails, visit <.link
                  href="/dev/mailbox"
                  style="color: #1976d2; text-decoration: underline;"
                >the mailbox page</.link>.
              </p>
            </div>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
          style="margin-bottom: 24px;"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button variant="primary" style="width: 100%; margin-top: 8px;">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="mdc-divider" style="margin: 24px 0;">
          <div style="text-align: center; margin: -10px 0;">
            <span style="background-color: var(--md-surface); padding: 0 16px; color: var(--md-text-secondary); font-size: 14px;">
              or
            </span>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
          />
          <.button
            variant="primary"
            style="width: 100%; margin-top: 8px;"
            name={@form[:remember_me].name}
            value="true"
          >
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button style="width: 100%; margin-top: 8px;">
            Log in only this time
          </.button>
        </.form>

        <div style="text-align: center; margin-top: 24px;">
          <.link
            navigate={~p"/users/forgot-password"}
            style="color: var(--md-primary); text-decoration: none; font-size: 14px; font-weight: 500;"
          >
            Forgot your password?
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:rogs_identity, RogsIdentity.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
