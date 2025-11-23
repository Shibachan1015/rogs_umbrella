defmodule Shinkanki.Repo.Migrations.CreateActionLogs do
  use Ecto.Migration

  def change do
    create table(:action_logs) do
      add :room_id, :string
      add :turn, :integer
      add :player_id, :string, null: true
      add :action, :string
      add :payload, :map

      timestamps()
    end
  end
end
