defmodule RogsIdentityWeb.UserLive.Login do
  use RogsIdentityWeb, :live_view

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="auth-card stack">
        <div>
          <h1 class="auth-title text-center">Log in</h1>
          <p class="auth-subtitle text-center">
            <%= if @current_scope do %>
              You need to reauthenticate to continue this secure action.
            <% else %>
              Don't have an account?
              <.link navigate={~p"/users/register"} class="link-muted" phx-no-format>
                Sign up
              </.link>
              to join the Torii network.
            <% end %>
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="info-callout">
          <.icon name="hero-information-circle" class="size-5 shrink-0 text-[var(--color-landing-gold)]" />
          <div>
            <strong>Local mail adapter active.</strong>
            <p class="text-sm text-[var(--color-landing-text-secondary)]">
              Review outgoing messages via the
              <.link href="/dev/mailbox" class="link-muted">
                dev mailbox
              </.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
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
          <.button variant="primary">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="torii-divider">
          <span>or</span>
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
          <.button variant="primary" name={@form[:remember_me].name} value="true">
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button>
            Log in only this time
          </.button>
        </.form>

        <div class="auth-helper">
          <.link navigate={~p"/users/forgot-password"} class="link-muted">
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
