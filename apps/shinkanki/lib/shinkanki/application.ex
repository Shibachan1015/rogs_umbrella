defmodule Shinkanki.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Shinkanki.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Shinkanki.PubSub}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Shinkanki.Supervisor)
  end
end
