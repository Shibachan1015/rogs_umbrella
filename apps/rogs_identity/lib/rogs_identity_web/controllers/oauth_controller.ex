defmodule RogsIdentityWeb.OAuthController do
  use RogsIdentityWeb, :controller
  plug Ueberauth

  alias RogsIdentity.Accounts
  alias RogsIdentityWeb.UserAuth

  def request(conn, params) do
    # return_toパラメータがあればセッションに保存
    conn =
      case params["return_to"] do
        nil -> conn
        return_to -> put_session(conn, :oauth_return_to, return_to)
      end

    # Ueberauth handles the redirect to the provider
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "認証に失敗しました。もう一度お試しください。")
    |> redirect(to: get_return_to(conn) || ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_attrs = %{
      email: get_email(auth),
      name: get_name(auth),
      provider: to_string(auth.provider),
      provider_id: to_string(auth.uid),
      avatar_url: get_avatar(auth)
    }

    case Accounts.find_or_create_oauth_user(user_attrs) do
      {:ok, user} ->
        return_to = get_return_to(conn) || "http://localhost:4000/lobby"
        token = RogsIdentity.Accounts.generate_user_session_token(user)

        conn
        |> put_flash(:info, "ログインしました。")
        |> put_session(:user_token, token)
        |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
        |> put_resp_cookie("_rogs_identity_web_user_remember_me", token,
          sign: true,
          max_age: 14 * 24 * 60 * 60,
          same_site: "Lax"
        )
        |> redirect(external: return_to)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "アカウントの作成に失敗しました。")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp get_email(auth) do
    auth.info.email
  end

  defp get_name(auth) do
    auth.info.name || auth.info.nickname || auth.info.first_name
  end

  defp get_avatar(auth) do
    auth.info.image
  end

  defp get_return_to(conn) do
    get_session(conn, :oauth_return_to)
  end
end
