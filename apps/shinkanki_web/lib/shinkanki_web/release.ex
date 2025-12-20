defmodule ShinkankiWeb.Release do
  @moduledoc """
  Release tasks for database migrations and seeding.
  Run with:
    /app/bin/rogs_umbrella eval 'ShinkankiWeb.Release.migrate()'
    /app/bin/rogs_umbrella eval 'ShinkankiWeb.Release.seed()'
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

  @doc """
  Run seed scripts to populate initial data.
  Only runs Shinkanki seeds (card data).
  """
  def seed do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Shinkanki.Repo, fn _repo ->
        # Run the seeds.exs file
        seeds_path = Application.app_dir(:shinkanki, "priv/repo/seeds.exs")

        if File.exists?(seeds_path) do
          Code.eval_file(seeds_path)
          IO.puts("✅ Seed completed successfully!")
        else
          IO.puts("⚠️ Seeds file not found at #{seeds_path}")
        end
      end)
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
