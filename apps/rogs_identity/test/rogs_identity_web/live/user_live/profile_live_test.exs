defmodule RogsIdentityWeb.UserLive.ProfileLiveTest do
  use RogsIdentityWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "profile page" do
    test "requires authentication" do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(build_conn(), ~p"/users/profile")
    end

    test "renders overview for signed in user", %{conn: conn} do
      user = RogsIdentity.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/users/profile")

      assert html =~ "Identity Overview"
      assert html =~ user.email
      assert html =~ "Connected Realms"
    end
  end
end
