defmodule RogsIdentityWeb.Api.AuthControllerTest do
  use RogsIdentityWeb.ConnCase, async: true

  import RogsIdentity.AccountsFixtures

  alias RogsIdentity.Accounts

  describe "POST /api/auth/login" do
    test "logs in user with email and password", %{conn: conn} do
      password = "HelloWorld123!"
      user = user_fixture()
      {:ok, {user, _}} = Accounts.update_user_password(user, %{password: password})

      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => password
        })

      response = json_response(conn, 200)

      assert %{
               "success" => true,
               "user" => %{
                 "id" => _id,
                 "email" => email,
                 "name" => _name
               }
             } = response

      assert email == user.email
      assert get_session(conn, :user_token)
    end

    test "returns error with invalid email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => "unknown@example.com",
          "password" => "HelloWorld123!"
        })

      assert %{"error" => "We couldn't verify those credentials."} = json_response(conn, 401)
    end

    test "returns error with invalid password", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })

      assert %{"error" => "We couldn't verify those credentials."} = json_response(conn, 401)
    end

    test "returns error with missing parameters", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{})

      assert %{"error" => "Missing required parameters: email and password, or token"} =
               json_response(conn, 400)
    end

    test "logs in user with magic link token", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = post(conn, ~p"/api/auth/login", %{"token" => token})

      response = json_response(conn, 200)

      assert %{
               "success" => true,
               "user" => %{
                 "id" => _id,
                 "email" => email
               }
             } = response

      assert email == user.email
    end

    test "returns error with invalid token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{"token" => "invalid_token"})

      assert %{"error" => "Invalid or expired token"} = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/register" do
    test "registers a new user", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/api/auth/register", %{
          "email" => email,
          "name" => "Test User"
        })

      response = json_response(conn, 200)

      assert %{
               "success" => true,
               "user" => %{
                 "id" => _id,
                 "email" => registered_email,
                 "name" => "Test User"
               }
             } = response

      assert registered_email == email

      assert get_session(conn, :user_token)
    end

    test "returns error with invalid email", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          "email" => "invalid-email",
          "name" => "Test User"
        })

      assert %{"error" => "Validation failed", "errors" => _errors} =
               json_response(conn, 422)
    end

    test "returns error with missing parameters", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", %{})

      assert %{"error" => "Missing required parameters: email and name"} =
               json_response(conn, 400)
    end
  end

  describe "GET /api/auth/me" do
    test "returns current user when authenticated", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/api/auth/me")

      response = json_response(conn, 200)

      assert %{
               "success" => true,
               "user" => %{
                 "id" => _id,
                 "email" => email,
                 "name" => _name,
                 "confirmed_at" => _confirmed_at,
                 "email_confirmed" => _email_confirmed
               }
             } = response

      assert email == user.email
    end

    test "returns error when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")

      assert %{"error" => "Authentication required"} = json_response(conn, 401)
    end
  end

  describe "POST /api/auth/logout" do
    test "logs out authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      token = get_session(conn, :user_token)
      assert token

      # Verify token exists in database before logout
      assert Accounts.get_user_by_session_token(token) != nil

      conn = post(conn, ~p"/api/auth/logout")

      assert %{"success" => true, "message" => "Logged out successfully"} =
               json_response(conn, 200)

      # After logout, token should be deleted from database
      assert Accounts.get_user_by_session_token(token) == nil
    end

    test "returns success even when not authenticated", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout")

      assert %{"success" => true, "message" => "Logged out successfully"} =
               json_response(conn, 200)
    end
  end
end
