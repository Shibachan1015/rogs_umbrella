defmodule ShinkankiWebWeb.Features.GameTest do
  use ShinkankiWebWeb.FeatureCase, async: false

  import RogsIdentity.AccountsFixtures

  @moduletag :feature

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  feature "logged in user can start a game", %{session: session, user: user} do
    session
    |> log_in_user(user)
    |> wait_for_live_view()
    |> visit("/game/new")
    |> wait_for_live_view()
    |> assert_has(Query.css("[data-phx-main]"))
  end

  feature "game page displays game title", %{session: session, user: user} do
    session
    |> log_in_user(user)
    |> wait_for_live_view()
    |> visit("/game/new")
    |> wait_for_live_view()
    # Verify we're on the game page by checking for game content
    |> assert_has(Query.text("神環記", count: :any, minimum: 1))
  end
end
