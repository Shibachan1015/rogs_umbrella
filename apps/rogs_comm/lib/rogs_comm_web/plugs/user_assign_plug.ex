defmodule RogsCommWeb.UserAssignPlug do
  @moduledoc """
  Assigns current user information from rogs_identity session to conn.assigns.

  This plug reads the user_token from the shared session cookie
  and fetches the user information, then assigns it to conn.assigns
  for use in LiveViews and Channels.
  """

  import Plug.Conn

  alias RogsIdentity.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    # Read user_token from session (shared with rogs_identity)
    user_token = get_session(conn, :user_token)

    case user_token do
      nil ->
        assign_anonymous_user(conn)

      token ->
        case Accounts.get_user_by_session_token(token) do
          {user, _token_inserted_at} ->
            conn
            |> assign(:current_user_id, user.id)
            |> assign(:current_user_email, user.email)
            |> assign(:current_user, user)

          nil ->
            assign_anonymous_user(conn)
        end
    end
  end

  defp assign_anonymous_user(conn) do
    conn
    |> assign(:current_user_id, nil)
    |> assign(:current_user_email, nil)
    |> assign(:current_user, nil)
  end
end
