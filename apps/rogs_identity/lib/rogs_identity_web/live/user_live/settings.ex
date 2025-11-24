defmodule RogsIdentityWeb.UserLive.Settings do
  use RogsIdentityWeb, :live_view

  on_mount {RogsIdentityWeb.UserAuth, :require_sudo_mode}

  alias RogsIdentity.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="auth-card stack">
        <div>
          <h1 class="auth-title text-left">Account Settings</h1>
          <p class="auth-subtitle">
            Tune your identity, contact email, credentials, and active sessions.
          </p>
        </div>

        <div :if={!@email_confirmed} class="info-callout info-callout--warning">
          <.icon name="hero-exclamation-triangle-mini" class="size-5 shrink-0" />
          <div>
            <strong>Email not confirmed</strong>
            <p class="text-sm text-[var(--color-landing-text-secondary)] mb-2">
              Please confirm your address to unlock the full experience.
            </p>
            <button
              phx-click="resend_confirmation"
              phx-disable-with="Sending..."
              class="cta-button cta-outline inline"
            >
              Resend confirmation email
            </button>
          </div>
        </div>

        <div :if={@email_confirmed} class="info-callout info-callout--success">
          <.icon name="hero-check-circle" class="size-5 shrink-0" />
          <div>
            <strong>Email confirmed</strong>
            <p class="text-sm text-[var(--color-landing-text-secondary)]">
              You have access to all secure interactions.
            </p>
          </div>
        </div>

        <section class="stack">
          <h2 class="section-title">Display name</h2>
          <p class="section-copy">
            Optional label shown across chat and game surfaces.
          </p>
          <.form for={@name_form} id="name_form" phx-submit="update_name" phx-change="validate_name">
            <.input
              field={@name_form[:name]}
              type="text"
              label="Display Name"
              placeholder="Optional"
              autocomplete="name"
            />
            <.button variant="primary" phx-disable-with="Saving...">Save Name</.button>
          </.form>
        </section>

        <div class="torii-divider" aria-hidden="true"></div>

        <section class="stack">
          <h2 class="section-title">Contact email</h2>
          <p class="section-copy">
            This address receives verification, login, and recovery notices.
          </p>
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
            />
            <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
          </.form>
        </section>

        <div class="torii-divider" aria-hidden="true"></div>

        <section class="stack">
          <h2 class="section-title">Password</h2>
          <p class="section-copy">
            Set a new password with TRDS-aligned strength expectations.
          </p>
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
            />
            <.button variant="primary" phx-disable-with="Saving...">
              Save Password
            </.button>
          </.form>
        </section>

        <div class="torii-divider" aria-hidden="true"></div>

        <section class="stack">
          <h2 class="section-title">Active sessions</h2>
          <p class="section-copy">
            Sign out remote devices or verify the current session.
          </p>

          <div :if={@sessions == []} class="auth-helper">
            No active sessions found.
          </div>

          <div :if={@sessions != []} class="session-list">
            <div
              :for={{session, index} <- Enum.with_index(@sessions)}
              class={[
                "session-card",
                session.is_current && "session-card--current"
              ]}
            >
              <div>
                <div style="display:flex; align-items:center; gap:0.5rem; margin-bottom:0.35rem;">
                  <span style="font-weight:600;">
                    {if session.is_current, do: "Current Session", else: "Session #{index + 1}"}
                  </span>
                  <span :if={session.is_current} class="badge-pill">Active</span>
                </div>
                <div class="session-card__meta">
                  <p>
                    Signed in: {Calendar.strftime(
                      session.authenticated_at || session.inserted_at,
                      "%B %d, %Y at %I:%M %p"
                    )}
                  </p>
                  <p>
                    Last activity: {Calendar.strftime(session.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </p>
                </div>
              </div>
              <button
                :if={!session.is_current}
                phx-click="delete_session"
                phx-value-session-id={session.id}
                phx-disable-with="Deleting..."
                class="cta-button cta-outline inline"
              >
                Sign Out
              </button>
            </div>
          </div>

          <div :if={@sessions != [] and length(@sessions) > 1} style="margin-top: 1rem;">
            <button
              phx-click="delete_all_other_sessions"
              phx-disable-with="Signing out..."
              class="cta-button cta-outline"
            >
              Sign out from all other devices
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user
    name_changeset = Accounts.change_user_name(user, %{})
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    # Get current session token from session
    current_token = Map.get(session, "user_token")

    # Get all active sessions with current session marked
    sessions = Accounts.list_user_session_tokens(user, current_token)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_confirmed, Accounts.email_confirmed?(user))
      |> assign(:name_form, to_form(name_changeset, as: "user"))
      |> assign(:email_form, to_form(email_changeset, as: "user"))
      |> assign(:password_form, to_form(password_changeset, as: "user"))
      |> assign(:trigger_submit, false)
      |> assign(:sessions, sessions)
      |> assign(:current_token, current_token)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_name", params, socket) do
    %{"user" => user_params} = params

    name_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.update_user_name(user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display name updated successfully.")
         |> assign(:name_form, to_form(Accounts.change_user_name(user, %{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, name_form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_event("resend_confirmation", _params, socket) do
    user = socket.assigns.current_scope.user

    if !Accounts.email_confirmed?(user) do
      Accounts.deliver_confirmation_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )

      {:noreply,
       socket
       |> put_flash(
         :info,
         "If your email is in our system, you will receive confirmation instructions shortly."
       )
       |> assign(:email_confirmed, Accounts.email_confirmed?(user))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_session", %{"session-id" => session_id}, socket) do
    user = socket.assigns.current_scope.user
    current_token = socket.assigns.current_token

    case Accounts.delete_user_session_token_by_id(user, session_id) do
      :ok ->
        # Reload sessions
        sessions = Accounts.list_user_session_tokens(user, current_token)

        {:noreply,
         socket
         |> put_flash(:info, "Session signed out successfully.")
         |> assign(:sessions, sessions)}

      :error ->
        {:noreply, put_flash(socket, :error, "Failed to delete session.")}
    end
  end

  @impl true
  def handle_event("delete_all_other_sessions", _params, socket) do
    user = socket.assigns.current_scope.user
    current_token = socket.assigns.current_token

    if current_token do
      deleted_count = Accounts.delete_all_other_sessions(user, current_token)

      # Reload sessions (should only have current one now)
      sessions = Accounts.list_user_session_tokens(user, current_token)
      sessions = Enum.map(sessions, fn session -> Map.delete(session, :token) end)

      {:noreply,
       socket
       |> put_flash(:info, "Signed out from #{deleted_count} other device(s).")
       |> assign(:sessions, sessions)}
    else
      {:noreply, put_flash(socket, :error, "Unable to identify current session.")}
    end
  end
end
