defmodule Shinkanki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # In test environment, we skip starting the Repo to allow pure logic tests without DB.
      (if Mix.env() != :test, do: Shinkanki.Repo, else: nil),
      # Start the PubSub system
      {Phoenix.PubSub, name: Shinkanki.PubSub},
      # Start the Registry for Game Servers
      {Registry, keys: :unique, name: Shinkanki.GameRegistry},
      # Start the DynamicSupervisor for Game Servers
      {DynamicSupervisor, strategy: :one_for_one, name: Shinkanki.GameSupervisor}
    ]
    |> Enum.reject(&is_nil/1)

    Supervisor.start_link(children, strategy: :one_for_one, name: Shinkanki.Supervisor)
  end
end
