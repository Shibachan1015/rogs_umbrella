defmodule RogsCommWeb.UserAuthHooks do
  @moduledoc """
  LiveView hooks for user authentication.
  """

  alias RogsIdentity.Accounts

  def on_mount(:assign_current_user, _params, session, socket) do
    user_token = Map.get(session, "user_token")

    socket =
      case user_token do
        nil ->
          assign_anonymous_user(socket)

        token ->
          case Accounts.get_user_by_session_token(token) do
            {user, _token_inserted_at} ->
              socket
              |> Phoenix.LiveView.assign(:current_user_id, user.id)
              |> Phoenix.LiveView.assign(:current_user_email, user.email)
              |> Phoenix.LiveView.assign(:current_user, user)
              |> Phoenix.LiveView.assign(:display_name, user.email)

            nil ->
              assign_anonymous_user(socket)
          end
      end

    {:cont, socket}
  end

  defp assign_anonymous_user(socket) do
    socket
    |> Phoenix.LiveView.assign(:current_user_id, nil)
    |> Phoenix.LiveView.assign(:current_user_email, nil)
    |> Phoenix.LiveView.assign(:current_user, nil)
    |> Phoenix.LiveView.assign(:display_name, "anonymous")
  end
end
