defmodule RogsIdentityWeb.OAuthController do
  use RogsIdentityWeb, :controller
  plug Ueberauth

  alias RogsIdentity.Accounts

  def request(%{assigns: %{current_scope: %{user: %Accounts.User{} = _user}}} = conn, params) do
    # return_toパラメータがあればセッションに保存
    conn =
      case params["return_to"] do
        nil -> conn
        return_to -> put_session(conn, :oauth_return_to, return_to)
      end

    # Ueberauth handles the redirect to the provider
    conn
  end

  def request(conn, _params) do
    conn
    |> put_flash(:error, "外部アカウントを連携するには先にログインしてください。")
    |> redirect(to: ~p"/users/log-in")
    |> halt()
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "認証に失敗しました。もう一度お試しください。")
    |> redirect(to: get_return_to(conn) || ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth, current_scope: %{user: user}}} = conn, _params)
      when not is_nil(user) do
    user_attrs = %{
      provider: to_string(auth.provider),
      provider_id: to_string(auth.uid),
      avatar_url: get_avatar(auth),
      email: get_email(auth),
      name: get_name(auth)
    }

    case Accounts.link_user_oauth(user, user_attrs) do
      {:ok, _updated_user} ->
        return_to = get_safe_return_to(conn)

        conn
        |> put_flash(:info, "#{String.capitalize(user_attrs.provider)}アカウントを連携しました。")
        |> redirect(to: return_to)

      {:error, :taken} ->
        conn
        |> put_flash(:error, "この#{String.capitalize(user_attrs.provider)}アカウントは既に別ユーザーに使用されています。")
        |> redirect(to: ~p"/users/settings")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "外部アカウントの連携に失敗しました。")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "外部アカウントを連携するにはログインしてください。")
    |> redirect(to: ~p"/users/log-in")
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

  # セキュリティ: リダイレクト先を検証し、安全なパスのみ許可
  defp get_safe_return_to(conn) do
    case get_return_to(conn) do
      nil ->
        "/lobby"

      path when is_binary(path) ->
        if safe_return_path?(path), do: path, else: "/lobby"

      _ ->
        "/lobby"
    end
  end

  # 安全なパスの検証: 相対パスのみ許可、外部URLを拒否
  defp safe_return_path?(path) when is_binary(path) do
    String.starts_with?(path, "/") and
      not String.contains?(path, "://") and
      not String.starts_with?(path, "//")
  end
end
