defmodule Shinkanki.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :akasha, :integer, null: false
      add :role, :string, null: false
      add :player_order, :integer, null: false
      add :game_session_id, references(:game_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :binary_id

      timestamps()
    end

    create index(:players, [:game_session_id])
    create unique_index(:players, [:game_session_id, :player_order])
  end
end
