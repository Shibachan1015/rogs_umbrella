defmodule ShinkankiWebWeb.UserSessionController do
  use ShinkankiWebWeb, :controller

  alias RogsIdentity.Accounts

  @remember_me_cookie "_rogs_identity_web_user_remember_me"
  @max_age 60 * 60 * 24 * 60
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "ログインしました")
      |> log_in_user(user, user_params)
    else
      conn
      |> put_flash(:error, "メールアドレスまたはパスワードが正しくありません")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  # 登録後の自動ログイン用エンドポイント（トークンベース）
  def auto_login(conn, %{"token" => encoded_token, "redirect" => redirect}) do
    # Base64デコード（URL-safe Base64をデコード）
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, token} ->
        case Accounts.get_user_by_session_token(token) do
          {user, _inserted_at} ->
            # redirectパラメータをパスに変換（文字列の場合はそのまま、~pの場合はto_string）
            redirect_path = if is_binary(redirect), do: redirect, else: redirect

            conn
            |> put_flash(:info, "アカウントを作成しました。プロフィールを設定してください。")
            |> log_in_user_with_redirect(user, %{}, redirect_path)

          nil ->
            conn
            |> put_flash(:error, "トークンが無効です")
            |> redirect(to: ~p"/users/log-in")
        end

      :error ->
        conn
        |> put_flash(:error, "トークンの形式が不正です")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def auto_login(conn, _params) do
    conn
    |> put_flash(:error, "パラメータが不正です")
    |> redirect(to: ~p"/users/log-in")
  end

  def delete(conn, _params) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      ShinkankiWebWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> put_flash(:info, "ログアウトしました")
    |> log_out_user()
  end

  # Helpers

  defp log_in_user(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    # セッションからreturn_toを取得（renew_sessionでクリアされる前に）
    return_to = get_session(conn, :user_return_to) || ~p"/lobby"
    # return_toを文字列に変換（URI構造体の場合はto_string）
    redirect_path = if is_binary(return_to), do: return_to, else: to_string(return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_remember_user(token, params)
    |> redirect(to: redirect_path)
  end

  # redirectパラメータを受け取る場合のヘルパー
  defp log_in_user_with_redirect(conn, user, params, redirect_path) do
    token = Accounts.generate_user_session_token(user)
    # redirect_pathを文字列に変換（URI構造体の場合はto_string）
    path = if is_binary(redirect_path), do: redirect_path, else: to_string(redirect_path)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_remember_user(token, params)
    |> redirect(to: path)
  end

  defp log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/lobby")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_remember_user(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_remember_user(conn, _token, _params) do
    conn
  end
end
