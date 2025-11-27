defmodule Shinkanki.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :turn, :integer, default: 1
      add :forest, :integer, null: false
      add :culture, :integer, null: false
      add :social, :integer, null: false
      add :life_index, :integer, null: false
      add :dao_pool, :integer, default: 0
      add :status, :string, default: "active"
      add :seed, :string

      timestamps()
    end

    create index(:game_sessions, [:status])
  end
end
