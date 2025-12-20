defmodule ShinkankiWebWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by feature tests
  using Wallaby for browser-based testing.

  Such tests rely on `Wallaby` for browser automation and
  must run with `mix test --include feature`.

  ## Usage

      use ShinkankiWebWeb.FeatureCase

      feature "user can view game page", %{session: session} do
        session
        |> visit("/")
        |> assert_has(Query.text("神環記"))
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      alias ShinkankiWebWeb.Router.Helpers, as: Routes

      import Wallaby.Query
      import ShinkankiWebWeb.FeatureCase.Helpers
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Shinkanki.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(RogsIdentity.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(RogsComm.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Shinkanki.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(RogsIdentity.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(RogsComm.Repo, {:shared, self()})
    end

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Shinkanki.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    {:ok, session: session}
  end

  defmodule Helpers do
    @moduledoc """
    Helper functions for feature tests.
    """

    use Wallaby.DSL

    @doc """
    Log in a user for feature tests.
    """
    def log_in_user(session, user) do
      session
      |> visit("/users/log-in")
      |> fill_in(Query.text_field("メールアドレス"), with: user.email)
      |> fill_in(Query.text_field("パスワード"), with: "valid_password123")
      |> click(Query.button("ログイン"))
    end

    @doc """
    Wait for LiveView to be connected.
    """
    def wait_for_live_view(session) do
      assert_has(session, Query.css("[data-phx-main]", visible: true))
    end

    @doc """
    Click on a card by its ID.
    """
    def click_card(session, card_id) do
      session
      |> click(Query.css("[phx-value-card-id='#{card_id}']"))
    end

    @doc """
    Assert that hand cards are displayed.
    """
    def assert_hand_cards_visible(session, count) do
      assert_has(session, Query.css("[phx-click='select_card']", count: count))
    end
  end
end
