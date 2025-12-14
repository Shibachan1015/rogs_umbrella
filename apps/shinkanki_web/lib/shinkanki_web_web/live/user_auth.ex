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
            maybe_dev_user(socket)
        end

      _ ->
        maybe_dev_user(socket)
    end
  end

  # 開発環境でのバイパス
  defp maybe_dev_user(socket) do
    if Application.get_env(:rogs_identity, :dev_bypass_auth, false) do
      dev_user = get_or_create_dev_user()
      assign(socket, :current_user, dev_user)
    else
      assign(socket, :current_user, nil)
    end
  end

  defp get_or_create_dev_user do
    email = "dev@example.com"
    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          email: email,
          password: "devpassword123"
        })
        user

      user ->
        user
    end
  end
end
