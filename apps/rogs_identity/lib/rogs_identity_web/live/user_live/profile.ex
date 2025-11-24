defmodule RogsIdentityWeb.UserLive.Profile do
  use RogsIdentityWeb, :live_view

  on_mount {RogsIdentityWeb.UserAuth, :require_authenticated}

  alias RogsIdentity.Accounts

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user
    current_token = session["user_token"]
    sessions = Accounts.list_user_session_tokens(user, current_token)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:email_confirmed, Accounts.email_confirmed?(user))
     |> assign(:sessions, sessions)
     |> assign(:federated_apps, federated_apps())
     |> assign(:current_token, current_token)}
  end

  defp federated_apps do
    Application.get_env(:rogs_identity, :federated_apps, default_apps())
    |> Enum.map(fn app ->
      app
      |> Map.put_new(:status, :connected)
      |> Map.put_new(:scopes, [])
    end)
  end

  defp default_apps do
    [
      %{
        id: :rogs_identity,
        name: "Torii Identity Core",
        description: "Primary credential authority for 神環記.",
        scopes: ["sessions", "profile"],
        surface: :dashboard,
        url: "http://localhost:4001/users/settings",
        status: :connected
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="auth-card stack">
        <section>
          <h1 class="auth-title text-left">Identity Overview</h1>
          <p class="auth-subtitle">
            Review your Torii signature, connected realms, and recent sessions.
          </p>

          <div class="profile-overview">
            <div>
              <p class="profile-label">Display name</p>
              <p class="profile-value">
                {if @user.name && @user.name != "", do: @user.name, else: "—"}
              </p>
            </div>
            <div>
              <p class="profile-label">Email</p>
              <p class="profile-value">{@user.email}</p>
            </div>
            <div>
              <p class="profile-label">Status</p>
              <span class={["badge-pill", @email_confirmed && "badge-pill--success"]}>
                {if @email_confirmed, do: "Confirmed", else: "Pending"}
              </span>
            </div>
          </div>
        </section>

        <div class="torii-divider" aria-hidden="true"></div>

        <section class="stack">
          <div class="section-header">
            <h2 class="section-title">Connected Realms</h2>
            <p class="section-copy">SSO surfaces that trust your Torii identity.</p>
          </div>

          <div class="connection-grid">
            <div
              :for={app <- @federated_apps}
              class="connection-card"
            >
              <div class="connection-head">
                <div>
                  <p class="connection-title">{app.name}</p>
                  <p class="connection-subtitle">{app.description}</p>
                </div>
                <span class={["badge-pill", status_class(app.status)]}>
                  {status_label(app.status)}
                </span>
              </div>
              <p class="connection-scopes">
                {Enum.join(app.scopes, " · ")}
              </p>
              <div class="connection-actions">
                <.link :if={app.url} href={app.url} class="cta-button cta-outline inline">
                  Open surface
                </.link>
              </div>
            </div>
          </div>
        </section>

        <div class="torii-divider" aria-hidden="true"></div>

        <section class="stack">
          <div class="section-header">
            <h2 class="section-title">Session Footprints</h2>
            <p class="section-copy">
              Track where your credential is currently active.
            </p>
          </div>

          <div :if={@sessions == []} class="auth-helper">
            No active sessions detected.
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
                  <span :if={session.is_current} class="badge-pill">Here</span>
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
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp status_label(:connected), do: "Connected"
  defp status_label(:pending), do: "Pending"
  defp status_label(_), do: "Unknown"

  defp status_class(:connected), do: "badge-pill--success"
  defp status_class(:pending), do: "badge-pill--warning"
  defp status_class(_), do: nil
end
