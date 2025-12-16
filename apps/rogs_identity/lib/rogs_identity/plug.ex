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
  In development, can bypass authentication with :dev_bypass_auth config.
  """
  # セキュリティ: 開発バイパスはコンパイル時に決定（本番では絶対に有効化されない）
  @dev_bypass_enabled Application.compile_env(:rogs_identity, :dev_bypass_auth, false) and
                        Application.compile_env(:rogs_identity, :env) == :dev

  def fetch_current_user(conn, _opts) do
    # 開発環境でのバイパスチェック（コンパイル時に決定済み）
    if @dev_bypass_enabled do
      fetch_current_user_with_bypass(conn)
    else
      fetch_current_user_normal(conn)
    end
  end

  defp fetch_current_user_with_bypass(conn) do
    # まず通常の認証を試みる
    case fetch_current_user_normal(conn) do
      %{assigns: %{current_user: nil}} = conn ->
        # ログインしていない場合、開発用ユーザーを取得または作成
        dev_user = get_or_create_dev_user()
        conn
        |> assign(:current_user, dev_user)
        |> assign(:current_scope, Scope.for_user(dev_user))

      conn ->
        conn
    end
  end

  defp fetch_current_user_normal(conn) do
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

  defp get_or_create_dev_user do
    email = "dev@example.com"
    case Accounts.get_user_by_email(email) do
      nil ->
        # 開発用ユーザーを作成
        {:ok, user} = Accounts.register_user(%{
          email: email,
          password: "devpassword123"
        })
        user

      user ->
        user
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
    case get_session(conn, :user_token) do
      token when is_binary(token) ->
        {token, conn}

      nil ->
        conn = fetch_cookies(conn, signed: [@remember_me_cookie])

        case conn.cookies[@remember_me_cookie] do
          token when is_binary(token) ->
            {token, put_session(conn, :user_token, token)}

          nil ->
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
