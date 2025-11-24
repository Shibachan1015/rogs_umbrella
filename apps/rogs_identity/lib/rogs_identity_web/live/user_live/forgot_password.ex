defmodule RogsIdentityWeb.UserLive.ForgotPassword do
  use RogsIdentityWeb, :live_view

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="auth-card stack" style="max-width: 420px;">
        <div class="text-center">
          <h1 class="auth-title">Forgot your password?</h1>
          <p class="auth-subtitle">
            We'll send reset instructions to your email.
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="info-callout">
          <.icon
            name="hero-information-circle"
            class="size-5 shrink-0 text-[var(--color-landing-gold)]"
          />
          <div>
            <strong>Local mail adapter active.</strong>
            <p class="text-sm text-[var(--color-landing-text-secondary)]">
              Visit the <.link href="/dev/mailbox" class="link-muted">mailbox page</.link>
              to preview outgoing messages.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="forgot_password_form"
          phx-submit="submit"
        >
          <.input
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.button variant="primary">
            Send reset instructions <span aria-hidden="true">→</span>
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
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => ""}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => %{"email" => email}}, socket) do
    # Check rate limit
    key = "password_reset:#{email}"
    attempt_count = RogsIdentityWeb.Plug.RateLimit.get_attempt_count(key, 3600)

    if attempt_count >= 3 do
      {:noreply,
       socket
       |> put_flash(:error, "Too many password reset requests. Please try again later.")}
    else
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_password_reset_instructions(
          user,
          &url(~p"/users/reset-password/#{&1}")
        )
      end

      # Record attempt
      record_password_reset_attempt(key)

      info =
        "If your email is in our system, you will receive instructions to reset your password shortly."

      {:noreply,
       socket
       |> put_flash(:info, info)
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  defp record_password_reset_attempt(key) do
    table = get_or_create_rate_limit_table()
    now = System.system_time(:second)

    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, [now]})

      [{^key, timestamps}] ->
        window_start = now - 3600
        filtered_timestamps = Enum.filter(timestamps, fn ts -> ts >= window_start end)
        :ets.insert(table, {key, [now | filtered_timestamps]})
    end
  end

  defp get_or_create_rate_limit_table do
    case :ets.whereis(:rate_limit_table) do
      :undefined ->
        :ets.new(:rate_limit_table, [:set, :public, :named_table])

      table ->
        table
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:rogs_identity, RogsIdentity.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end
end
