defmodule RogsCommWeb.UserSocket do
  @moduledoc """
  Socket entry-point for chat connections.
  """

  use Phoenix.Socket

  alias RogsIdentity.Accounts

  channel "room:*", RogsCommWeb.ChatChannel
  channel "signal:*", RogsCommWeb.SignalingChannel

  @impl true
  def connect(params, socket, connect_info) do
    # Try to get user_token from params or session
    user_token = Map.get(params, "user_token") || get_user_token_from_session(connect_info)

    socket =
      case user_token do
        nil ->
          socket
          |> assign(:user_id, nil)
          |> assign(:user_email, nil)

        token ->
          case Accounts.get_user_by_session_token(token) do
            {user, _token_inserted_at} ->
              socket
              |> assign(:user_id, user.id)
              |> assign(:user_email, user.email)

            nil ->
              socket
              |> assign(:user_id, nil)
              |> assign(:user_email, nil)
          end
      end

    {:ok, socket}
  end

  defp get_user_token_from_session(connect_info) do
    case Map.get(connect_info, :session) do
      %{"user_token" => token} -> token
      _ -> nil
    end
  end

  @impl true
  def id(_socket), do: nil
end
