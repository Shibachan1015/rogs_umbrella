defmodule RogsIdentity.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RogsIdentityWeb.Telemetry,
      RogsIdentity.Repo,
      {DNSCluster, query: Application.get_env(:rogs_identity, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RogsIdentity.PubSub},
      # Start a worker by calling: RogsIdentity.Worker.start_link(arg)
      # {RogsIdentity.Worker, arg},
      # Start to serve requests, typically the last entry
      RogsIdentityWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RogsIdentity.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RogsIdentityWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
