defmodule Shinkanki.Repo.Migrations.CreateGameActions do
  use Ecto.Migration

  def change do
    create table(:game_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :turn, :integer, null: false
      add :action_type, :string, null: false
      add :details, :map

      add :game_session_id, references(:game_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all)
      add :action_card_id, references(:action_cards, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:game_actions, [:game_session_id])
    create index(:game_actions, [:player_id])
    create index(:game_actions, [:game_session_id, :turn])
  end
end
