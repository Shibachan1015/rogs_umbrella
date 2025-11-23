defmodule RogsIdentityWeb.Api.AuthController do
  use RogsIdentityWeb, :controller

  alias RogsIdentity.Accounts

  @doc """
  Login endpoint for API.
  Accepts email/password or magic link token.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})

      user ->
        token = Accounts.generate_user_session_token(user)
        conn = put_token_in_session(conn, token)

        json(conn, %{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          }
        })
    end
  end

  def login(conn, %{"token" => token}) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _tokens_to_disconnect}} ->
        session_token = Accounts.generate_user_session_token(user)
        conn = put_token_in_session(conn, session_token)

        json(conn, %{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name
          }
        })

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired token"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: email and password, or token"})
  end

  @doc """
  Register endpoint for API.
  """
  def register(conn, %{"email" => email, "name" => name}) do
    case Accounts.register_user(%{email: email, name: name}) do
      {:ok, user} ->
        # Generate session token and log in the user
        token = Accounts.generate_user_session_token(user)
        conn = put_token_in_session(conn, token)

        json(conn, %{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            confirmed_at: user.confirmed_at
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Validation failed",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: email and name"})
  end

  @doc """
  Get current authenticated user information.
  """
  def me(conn, _params) do
    case conn.assigns.current_scope do
      %{user: user} when not is_nil(user) ->
        json(conn, %{
          success: true,
          user: %{
            id: user.id,
            email: user.email,
            name: user.name,
            confirmed_at: user.confirmed_at,
            email_confirmed: Accounts.email_confirmed?(user)
          }
        })

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end

  @doc """
  Logout endpoint for API.
  """
  def logout(conn, _params) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      RogsIdentityWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> configure_session(drop: true)
    |> json(%{success: true, message: "Logged out successfully"})
  end

  # Helper functions

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
