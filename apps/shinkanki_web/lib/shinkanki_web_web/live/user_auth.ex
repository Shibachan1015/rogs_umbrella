defmodule ShinkankiWebWeb.UserAuth do
  @moduledoc """
  LiveView用の認証ヘルパー
  """
  import Phoenix.Component

  alias RogsIdentity.Accounts

  @doc """
  LiveView mount時にセッションからユーザー情報を取得
  """
  def on_mount(:default, _params, session, socket) do
    socket = mount_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "ログインしてください")
        |> Phoenix.LiveView.redirect(to: "/users/log-in")

      {:halt, socket}
    end
  end

  defp mount_current_user(socket, session) do
    case session do
      %{"user_token" => user_token} ->
        case Accounts.get_user_by_session_token(user_token) do
          {user, _token_inserted_at} ->
            assign(socket, :current_user, user)

          nil ->
            assign(socket, :current_user, nil)
        end

      _ ->
        # Remember me cookie からトークンを取得（LiveViewでは直接アクセスできないので session経由）
        assign(socket, :current_user, nil)
    end
  end
end
