defmodule ShinkankiWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShinkankiWebWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:shinkanki_web, :dns_cluster_query) || :ignore},
      # Use Shinkanki.PubSub to share game state updates with shinkanki app
      # Note: This assumes Shinkanki.PubSub is already started by shinkanki app
      # If not available, fallback to local PubSub
      (if Code.ensure_loaded?(Shinkanki) and Process.whereis(Shinkanki.PubSub) != nil do
         nil
       else
         {Phoenix.PubSub, name: ShinkankiWeb.PubSub}
       end),
      # Start to serve requests, typically the last entry
      ShinkankiWebWeb.Endpoint
    ]
    |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShinkankiWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShinkankiWebWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
