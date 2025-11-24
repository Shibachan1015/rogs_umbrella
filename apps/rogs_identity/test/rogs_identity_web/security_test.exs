defmodule RogsIdentityWeb.SecurityTest do
  use RogsIdentityWeb.ConnCase, async: true

  import Ecto.Query
  import RogsIdentity.AccountsFixtures
  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.UserToken
  alias RogsIdentity.Repo
  alias RogsIdentityWeb.Plug.RateLimit

  describe "Rate Limiting" do
    setup do
      # Clean up rate limit table before each test
      case :ets.whereis(:rate_limit_table) do
        :undefined -> :ok
        table -> :ets.delete_all_objects(table)
      end

      :ok
    end

    test "allows requests within rate limit", %{conn: _conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Make 4 requests (under the limit of 5)
      for _ <- 1..4 do
        conn =
          build_conn()
          |> post(~p"/api/auth/login", %{
            "email" => user.email,
            "password" => "wrongpassword"
          })

        assert conn.status in [401, 429]
      end

      # 5th request should still be allowed (at the limit)
      conn =
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => password
        })

      assert conn.status == 200
    end

    test "blocks requests exceeding rate limit", %{conn: _conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Make 5 failed requests
      for _ <- 1..5 do
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })
      end

      # 6th request should be blocked
      conn =
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => password
        })

      assert conn.status == 429

      assert %{"error" => "Login attempts are cooling down. Hold for a moment and retry."} =
               json_response(conn, 429)
    end

    test "rate limit is per email address", %{conn: _conn} do
      password = "HelloWorld123!"
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, {user1, _}} = Accounts.update_user_password(user1, %{password: password})
      {:ok, {user2, _}} = Accounts.update_user_password(user2, %{password: password})

      # Exhaust rate limit for user1
      for _ <- 1..5 do
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user1.email,
          "password" => "wrongpassword"
        })
      end

      # user2 should still be able to login
      conn =
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user2.email,
          "password" => password
        })

      assert conn.status == 200
    end

    test "rate limit resets after window expires", %{conn: _conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Exhaust rate limit
      for _ <- 1..5 do
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })
      end

      # Reset the rate limit for testing
      key = "login:#{user.email}"
      RateLimit.reset(key)

      # Should be able to login now
      conn =
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => password
        })

      assert conn.status == 200
    end

    test "rate limit tracks attempts correctly", %{conn: _conn} do
      user = user_fixture()
      key = "login:#{user.email}"

      # Make 3 attempts
      for _ <- 1..3 do
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })
      end

      # Check attempt count
      assert RateLimit.get_attempt_count(key, 300) == 3
    end
  end

  describe "Session Fixation Attack Prevention" do
    test "session ID is renewed on login", %{conn: conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Create a session before login
      conn = init_test_session(conn, %{malicious_data: "should_be_cleared"})

      # Login
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => password
          }
        })

      # Session should be renewed (different session ID)
      # Note: In Phoenix, session renewal happens via configure_session(renew: true)
      # which changes the session cookie, not necessarily a visible session_id
      # The important thing is that malicious_data is cleared
      refute get_session(conn, :malicious_data)
      assert get_session(conn, :user_token)
    end

    test "session is cleared when logging in as different user", %{conn: conn} do
      password = "HelloWorld123!"
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, {user1, _}} = Accounts.update_user_password(user1, %{password: password})
      {:ok, {user2, _}} = Accounts.update_user_password(user2, %{password: password})

      # Login as user1
      conn = log_in_user(conn, user1)
      user1_token = get_session(conn, :user_token)
      assert user1_token

      # Store some data in session
      conn = put_session(conn, :some_data, "value")

      # Login as user2
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user2.email,
            "password" => password
          }
        })

      # Session should be cleared and new token set
      refute get_session(conn, :some_data)
      user2_token = get_session(conn, :user_token)
      assert user2_token
      assert user2_token != user1_token
    end

    test "session is not renewed when re-authenticating as same user", %{conn: conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Login
      conn = log_in_user(conn, user)
      original_token = get_session(conn, :user_token)
      conn = put_session(conn, :preserved_data, "should_stay")

      # Re-authenticate as same user
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => password
          }
        })

      # Session data should be preserved
      assert get_session(conn, :preserved_data) == "should_stay"
      # Token might be the same or different, but user should still be authenticated
      assert get_session(conn, :user_token)
    end
  end

  describe "Token Validation" do
    test "invalid token is rejected", %{conn: conn} do
      # Try to use an invalid token
      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, "invalid_token")
        |> get(~p"/api/auth/me")

      assert conn.status == 401
      assert %{"error" => "Authentication required"} = json_response(conn, 401)
    end

    test "expired token is rejected", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Manually expire the token by setting inserted_at to past
      Repo.update_all(
        from(t in UserToken, where: t.token == ^token),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> get(~p"/api/auth/me")

      assert conn.status == 401
      assert %{"error" => "Authentication required"} = json_response(conn, 401)
    end

    test "valid token is accepted", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/api/auth/me")

      assert conn.status == 200
      assert %{"success" => true, "user" => _} = json_response(conn, 200)
    end

    test "token is deleted after logout", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      token = get_session(conn, :user_token)

      # Verify token exists
      assert Accounts.get_user_by_session_token(token) != nil

      # Logout
      conn = post(conn, ~p"/api/auth/logout")

      # Token should be deleted
      assert Accounts.get_user_by_session_token(token) == nil
    end

    test "magic link token expires after validity period", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      # Manually expire the token
      expired_time = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -16, :minute)

      Repo.update_all(
        from(t in UserToken, where: t.context == "login"),
        set: [inserted_at: expired_time]
      )

      # Try to use expired token
      conn = post(conn, ~p"/api/auth/login", %{"token" => token})

      assert conn.status == 401
      assert %{"error" => "Invalid or expired token"} = json_response(conn, 401)
    end

    test "password reset token expires after validity period", %{conn: _conn} do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_password_reset_instructions(user, url)
        end)

      # Manually expire the token (7 hours ago)
      expired_time = NaiveDateTime.add(NaiveDateTime.utc_now(:second), -7, :hour)

      Repo.update_all(
        from(t in UserToken, where: t.context == "reset_password"),
        set: [inserted_at: expired_time]
      )

      # Try to use expired token
      user = Accounts.get_user_by_password_reset_token(token)
      assert user == nil
    end
  end
end
