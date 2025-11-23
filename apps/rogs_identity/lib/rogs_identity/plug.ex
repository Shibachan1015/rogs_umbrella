defmodule RogsIdentity.Plug do
  @moduledoc """
  Plugs for use in other applications (rogs_comm, shinkanki_web, etc.)

  These plugs allow other applications to authenticate users using
  the shared session from rogs_identity.

  ## Usage

  In your router:

      import RogsIdentity.Plug

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_current_user
      end

      pipeline :require_authenticated do
        plug :require_authenticated
      end

      scope "/", MyAppWeb do
        pipe_through [:browser, :require_authenticated]

        get "/protected", PageController, :protected
      end

  Or use the module functions directly:

      plug RogsIdentity.Plug, :fetch_current_user
      plug RogsIdentity.Plug, :require_authenticated
  """

  import Plug.Conn
  import Phoenix.Controller

  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.Scope

  @remember_me_cookie "_rogs_identity_web_user_remember_me"

  @doc """
  Fetches the current user from the session.
  Sets `conn.assigns.current_user` and `conn.assigns.current_scope`.
  """
  def fetch_current_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, _token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_scope, Scope.for_user(user))
    else
      nil ->
        conn
        |> assign(:current_user, nil)
        |> assign(:current_scope, Scope.for_user(nil))
    end
  end

  @doc """
  Requires the user to be authenticated.
  Returns 401 Unauthorized for API requests or redirects to login for browser requests.
  """
  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      if get_req_header(conn, "accept") |> Enum.any?(&String.contains?(&1, "json")) do
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
      else
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: get_login_url())
        |> halt()
      end
    end
  end

  # Plug implementation
  def init(opts), do: opts

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authenticated), do: require_authenticated(conn, [])

  def call(conn, opts) when is_list(opts) do
    case Keyword.get(opts, :action) do
      :fetch_current_user -> fetch_current_user(conn, opts)
      :require_authenticated -> require_authenticated(conn, opts)
      _ -> conn
    end
  end

  # Private helpers

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_session(conn, :user_token, token)}
      else
        nil
      end
    end
  end

  defp get_login_url do
    # Default to rogs_identity login URL
    # Can be configured via application config
    login_url = Application.get_env(:rogs_identity, :login_url, "/users/log-in")
    # If it's a full URL, extract just the path
    case URI.parse(login_url) do
      %URI{path: path} when path != "" -> path
      _ -> login_url
    end
  end
end
