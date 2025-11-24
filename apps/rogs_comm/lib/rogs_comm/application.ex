defmodule RogsComm.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize rate limiter ETS table
    RogsCommWeb.RateLimiter.init()

    children = [
      RogsCommWeb.Telemetry,
      RogsComm.Repo,
      {DNSCluster, query: Application.get_env(:rogs_comm, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RogsComm.PubSub},
      RogsComm.Cache.MessageCache,
      # Start a worker by calling: RogsComm.Worker.start_link(arg)
      # {RogsComm.Worker, arg},
      # Start to serve requests, typically the last entry
      RogsCommWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RogsComm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RogsCommWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
