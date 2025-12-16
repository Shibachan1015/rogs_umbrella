defmodule ShinkankiWeb.Release do
  @moduledoc """
  Release tasks for database migrations.
  Run with: /app/bin/rogs_umbrella eval 'ShinkankiWeb.Release.migrate()'
  """

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    [
      Shinkanki.Repo,
      RogsComm.Repo,
      RogsIdentity.Repo
    ]
  end

  defp load_app do
    Application.load(:shinkanki)
    Application.load(:rogs_comm)
    Application.load(:rogs_identity)
  end
end
