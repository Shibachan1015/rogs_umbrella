defmodule RogsIdentityWeb.UserLive.ForgotPassword do
  use RogsIdentityWeb, :live_view

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mdc-card" style="max-width: 400px; margin: 48px auto;">
        <div style="text-align: center; margin-bottom: 32px;">
          <h1 style="font-size: 24px; font-weight: 500; margin: 0 0 8px 0; color: var(--md-text-primary);">
            Forgot your password?
          </h1>
          <p style="font-size: 14px; color: var(--md-text-secondary); margin: 0;">
            We'll send password reset instructions to your email
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="mdc-card" style="background-color: #e3f2fd; padding: 16px; margin-bottom: 24px; border-radius: 4px;">
          <div style="display: flex; align-items: start; gap: 12px;">
            <span class="material-icons" style="color: #1976d2; font-size: 24px;">info</span>
            <div style="flex: 1;">
              <p style="margin: 0 0 4px 0; font-size: 14px; color: #1565c0;">You are running the local mail adapter.</p>
              <p style="margin: 0; font-size: 14px; color: #1565c0;">
                To see sent emails, visit <.link href="/dev/mailbox" style="color: #1976d2; text-decoration: underline;">the mailbox page</.link>.
              </p>
            </div>
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
          <.button variant="primary" style="width: 100%; margin-top: 8px;">
            Send reset instructions <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div style="text-align: center; margin-top: 24px;">
          <.link navigate={~p"/users/log-in"} style="color: var(--md-primary); text-decoration: none; font-size: 14px; font-weight: 500;">
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
