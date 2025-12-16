defmodule ShinkankiWebWeb.OAuthController do
  use ShinkankiWebWeb, :controller
  plug Ueberauth

  alias RogsIdentity.Accounts

  def request(conn, params) do
    # return_toパラメータがあればセッションに保存（内部パスのみ許可）
    conn =
      case params["return_to"] do
        nil -> conn
        return_to ->
          if safe_return_path?(return_to) do
            put_session(conn, :oauth_return_to, return_to)
          else
            conn
          end
      end

    # Ueberauth handles the redirect to the provider
    conn
  end

  # Validate that return path is internal and safe
  defp safe_return_path?(path) when is_binary(path) do
    # Must start with / and not contain protocol or double slashes
    String.starts_with?(path, "/") and
      not String.contains?(path, "://") and
      not String.starts_with?(path, "//")
  end
  defp safe_return_path?(_), do: false

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
        return_to = get_return_to(conn) || "/lobby"
        token = RogsIdentity.Accounts.generate_user_session_token(user)

        conn
        |> put_flash(:info, "ログインしました。")
        |> put_session(:user_token, token)
        |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
        |> put_resp_cookie("_rogs_identity_web_user_remember_me", token,
          sign: true,
          max_age: 14 * 24 * 60 * 60,
          same_site: "Strict",
          secure: true,
          http_only: true
        )
        |> redirect(to: return_to)

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
