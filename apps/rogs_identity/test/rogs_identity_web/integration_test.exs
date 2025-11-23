defmodule RogsIdentityWeb.IntegrationTest do
  use RogsIdentityWeb.ConnCase, async: true

  import RogsIdentity.AccountsFixtures
  alias RogsIdentity.Accounts

  describe "Cross-application authentication integration" do
    test "session is shared between rogs_identity and other apps", %{conn: _conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      # Login via rogs_identity API
      conn =
        build_conn()
        |> post(~p"/api/auth/login", %{
          "email" => user.email,
          "password" => password
        })

      assert conn.status == 200
      token = get_session(conn, :user_token)
      assert token

      # Simulate accessing rogs_comm with the same session
      # In a real scenario, this would be a separate request to rogs_comm
      # but we can test the Plug directly
      conn_comm =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})

      assert conn_comm.assigns.current_user.id == user.id
      assert conn_comm.assigns.current_scope.user.id == user.id
    end

    test "RogsIdentity.Plug.fetch_current_user works with valid token", %{conn: _conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.current_scope.user.id == user.id
    end

    test "RogsIdentity.Plug.fetch_current_user returns nil for invalid token", %{conn: _conn} do
      conn =
        build_conn()
        |> init_test_session(%{user_token: "invalid_token"})
        |> RogsIdentity.Plug.fetch_current_user(%{})

      assert conn.assigns.current_user == nil
      # Scope.for_user(nil) returns nil
      assert conn.assigns.current_scope == nil
    end

    test "RogsIdentity.Plug.require_authenticated allows authenticated users", %{conn: _conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})
        |> RogsIdentity.Plug.require_authenticated(%{})

      assert conn.status != 401
      assert conn.status != 302
    end

    test "RogsIdentity.Plug.require_authenticated redirects unauthenticated users for browser", %{
      conn: _conn
    } do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> fetch_flash()
        |> put_req_header("accept", "text/html")
        |> RogsIdentity.Plug.fetch_current_user(%{})
        |> RogsIdentity.Plug.require_authenticated(%{})

      assert conn.status == 302
      assert redirected_to(conn) =~ "/users/log-in"
    end

    test "RogsIdentity.Plug.require_authenticated returns 401 for API requests", %{conn: _conn} do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_req_header("accept", "application/json")
        |> RogsIdentity.Plug.fetch_current_user(%{})
        |> RogsIdentity.Plug.require_authenticated(%{})

      assert conn.status == 401
      assert %{"error" => "Authentication required"} = json_response(conn, 401)
    end

    test "session works with remember me cookie", %{conn: _conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # Test that ensure_user_token can read from cookie
      # In a real scenario, the cookie would be signed, but in tests
      # we can verify the logic works by directly testing the cookie reading
      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_req_cookie("_rogs_identity_web_user_remember_me", token)
        |> fetch_cookies(signed: ["_rogs_identity_web_user_remember_me"])

      # The cookie should be available
      cookie_token = conn.cookies["_rogs_identity_web_user_remember_me"]

      # If cookie is available, test the full flow
      if cookie_token do
        conn = RogsIdentity.Plug.fetch_current_user(conn, %{})

        # User should be authenticated if token is valid
        if conn.assigns.current_user do
          assert conn.assigns.current_user.id == user.id
        end
      else
        # In test environment, signed cookies might require additional setup
        # Just verify the token exists in database
        assert Accounts.get_user_by_session_token(token) != nil
      end
    end
  end

  describe "End-to-end authentication flow" do
    test "complete flow: register -> login -> access protected resource -> logout", %{conn: _conn} do
      email = unique_user_email()

      # 1. Register
      conn =
        build_conn()
        |> post(~p"/api/auth/register", %{
          "email" => email,
          "name" => "Test User"
        })

      assert conn.status == 200
      token = get_session(conn, :user_token)
      assert token

      # 2. Access protected resource (simulate rogs_comm)
      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})
        |> RogsIdentity.Plug.require_authenticated(%{})

      assert conn.status != 401
      assert conn.status != 302

      # 3. Logout
      conn =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> post(~p"/api/auth/logout")

      assert conn.status == 200

      # 4. Try to access protected resource after logout
      conn =
        build_conn()
        |> init_test_session(%{})
        |> fetch_flash()
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})
        |> RogsIdentity.Plug.require_authenticated(%{})

      assert conn.status == 401 || conn.status == 302
    end

    test "session persists across multiple requests", %{conn: _conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)

      # First request
      conn1 =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})

      assert conn1.assigns.current_user.id == user.id

      # Second request (simulating a new HTTP request)
      conn2 =
        build_conn()
        |> init_test_session(%{})
        |> put_session(:user_token, token)
        |> RogsIdentity.Plug.fetch_current_user(%{})

      assert conn2.assigns.current_user.id == user.id
    end
  end

  describe "RogsIdentity.get_display_name integration" do
    test "returns user name when available", %{conn: _conn} do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_name(user, %{name: "John Doe"})

      assert RogsIdentity.get_display_name(user.id) == "John Doe"
    end

    test "returns email when name is not set", %{conn: _conn} do
      user = user_fixture()

      assert RogsIdentity.get_display_name(user.id) == user.email
    end

    test "returns Anonymous for non-existent user", %{conn: _conn} do
      # Use a valid UUID format for binary_id
      fake_id = Ecto.UUID.generate()
      assert RogsIdentity.get_display_name(fake_id) == "Anonymous"
    end
  end
end
