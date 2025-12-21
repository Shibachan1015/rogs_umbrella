defmodule ShinkankiWebWeb.OAuthController do
  use ShinkankiWebWeb, :controller
  plug Ueberauth

  alias RogsIdentity.Accounts

  def request(%{assigns: %{current_scope: %{user: %Accounts.User{} = _user}}} = conn, params) do
    # return_toパラメータがあればセッションに保存（内部パスのみ許可）
    conn =
      case params["return_to"] do
        nil ->
          conn

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

  def request(conn, _params) do
    conn
    |> put_flash(:error, "外部アカウント連携はログイン後に利用できます。")
    |> redirect(to: ~p"/users/log-in")
    |> halt()
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
        return_to = get_return_to(conn) || ~p"/profile"

        conn
        |> put_flash(:info, "#{String.capitalize(user_attrs.provider)}アカウントを連携しました。")
        |> redirect(to: return_to)

      {:error, :taken} ->
        conn
        |> put_flash(
          :error,
          "この#{String.capitalize(user_attrs.provider)}アカウントは既に他のプレイヤーに使用されています。"
        )
        |> redirect(to: ~p"/profile")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "外部アカウントの連携に失敗しました。")
        |> redirect(to: ~p"/profile")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "外部アカウント連携はログイン後に利用できます。")
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
end
