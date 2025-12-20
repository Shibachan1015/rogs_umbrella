defmodule ShinkankiWebWeb.Features.LandingPageTest do
  use ShinkankiWebWeb.FeatureCase, async: false

  @moduletag :feature

  feature "user can view landing page", %{session: session} do
    session
    |> visit("/")
    |> assert_has(Query.css("body"))
  end

  feature "landing page shows main title", %{session: session} do
    session
    |> visit("/")
    |> assert_has(Query.text("神環記", count: :any, minimum: 1))
  end
end
