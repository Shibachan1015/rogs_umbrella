defmodule RogsGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RogsGameWeb.Telemetry,
      RogsGame.Repo,
      {DNSCluster, query: Application.get_env(:rogs_game, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RogsGame.PubSub},
      # Start a worker by calling: RogsGame.Worker.start_link(arg)
      # {RogsGame.Worker, arg},
      # Start to serve requests, typically the last entry
      RogsGameWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RogsGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RogsGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
