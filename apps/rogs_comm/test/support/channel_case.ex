defmodule RogsCommWeb.ChannelCase do
  @moduledoc """
  Test case module for channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      @endpoint RogsCommWeb.Endpoint
    end
  end

  setup tags do
    RogsComm.DataCase.setup_sandbox(tags)
    :ok
  end
end
