defmodule Shinkanki.Repo.Migrations.CreateTurnStates do
  use Ecto.Migration

  def change do
    create table(:turn_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :turn_number, :integer, null: false
      add :phase, :string, default: "event"
      add :available_cards, {:array, :binary_id}, default: []
      add :current_event_id, :binary_id
      add :event_choice, :string

      add :game_session_id, references(:game_sessions, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:turn_states, [:game_session_id])
    create unique_index(:turn_states, [:game_session_id, :turn_number])
  end
end
