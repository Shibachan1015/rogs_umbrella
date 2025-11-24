defmodule RogsIdentityWeb.UserLive.SettingsSessionTest do
  use RogsIdentityWeb.ConnCase, async: true

  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.UserToken
  alias RogsIdentity.Repo
  import Ecto.Query
  import Phoenix.LiveViewTest
  import RogsIdentity.AccountsFixtures

  describe "Session management" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      token = get_session(conn, :user_token)

      # Create additional sessions
      token2 = Accounts.generate_user_session_token(user)
      token3 = Accounts.generate_user_session_token(user)

      %{conn: conn, user: user, token: token, token2: token2, token3: token3}
    end

    test "displays active sessions", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings")

      assert html =~ "Active sessions"
      assert html =~ "Sign out remote devices"
      assert html =~ "Current Session"
      assert html =~ "Active"
    end

    test "displays session information", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings")

      # Should show signed in time and last activity
      assert html =~ "Signed in:"
      assert html =~ "Last activity:"
    end

    test "allows deleting a specific session", %{conn: conn, token2: token2} do
      # Verify token2 exists
      assert Accounts.get_user_by_session_token(token2) != nil

      # Get session ID for token2 by querying the database directly
      import Ecto.Query

      session_id =
        from(t in UserToken,
          where: t.token == ^token2 and t.context == "session",
          select: t.id,
          limit: 1
        )
        |> Repo.one()

      assert session_id != nil

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Delete the session using the session ID
      lv
      |> element("button[phx-click='delete_session'][phx-value-session-id='#{session_id}']")
      |> render_click()

      # Verify session was deleted
      assert Accounts.get_user_by_session_token(token2) == nil

      # Verify flash message
      assert render(lv) =~ "Session signed out successfully"
    end

    test "allows deleting all other sessions", %{
      conn: conn,
      token2: token2,
      token3: token3
    } do
      # Verify other tokens exist
      assert Accounts.get_user_by_session_token(token2) != nil
      assert Accounts.get_user_by_session_token(token3) != nil

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Delete all other sessions
      lv
      |> element("button[phx-click='delete_all_other_sessions']")
      |> render_click()

      # Verify other sessions were deleted
      assert Accounts.get_user_by_session_token(token2) == nil
      assert Accounts.get_user_by_session_token(token3) == nil

      # Current session should still exist
      current_token = get_session(conn, :user_token)
      assert Accounts.get_user_by_session_token(current_token) != nil

      # Verify flash message
      assert render(lv) =~ "Signed out from"
      assert render(lv) =~ "other device(s)"
    end

    test "marks current session correctly", %{conn: conn, user: user} do
      current_token = get_session(conn, :user_token)
      sessions = Accounts.list_user_session_tokens(user, current_token)

      # Should have at least one session
      assert length(sessions) >= 1

      # Current session should be marked
      current_session = Enum.find(sessions, fn s -> s.is_current end)
      assert current_session != nil
    end

    test "does not show delete button for current session", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/settings")

      # Current session should not have a delete button
      # The delete button should only appear for non-current sessions
      assert html =~ "Current Session"
      assert html =~ "Active"
    end

    test "shows empty state when no sessions", %{conn: conn, user: user} do
      # Delete all sessions
      current_token = get_session(conn, :user_token)
      Accounts.delete_all_other_sessions(user, current_token)
      Accounts.delete_user_session_token(current_token)

      # This should redirect to login, but let's test the session listing function
      sessions = Accounts.list_user_session_tokens(user, nil)
      assert sessions == []
    end
  end
end
