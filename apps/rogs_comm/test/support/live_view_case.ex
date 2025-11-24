defmodule RogsCommWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a LiveView connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import RogsCommWeb.ConnCase
      import RogsComm.RoomsFixtures

      use RogsCommWeb, :verified_routes

      @endpoint RogsCommWeb.Endpoint
    end
  end

  setup tags do
    RogsComm.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
