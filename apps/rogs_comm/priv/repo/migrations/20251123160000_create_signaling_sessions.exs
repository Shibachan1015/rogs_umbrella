defmodule RogsComm.Repo.Migrations.CreateSignalingSessions do
  use Ecto.Migration

  def change do
    create table(:signaling_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id), null: false
      add :from_user_id, :binary_id, null: false
      add :to_user_id, :binary_id
      add :event_type, :string, null: false
      add :payload, :jsonb, null: false
      add :created_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:signaling_sessions, [:room_id])
    create index(:signaling_sessions, [:from_user_id])
    create index(:signaling_sessions, [:to_user_id])
    create index(:signaling_sessions, [:created_at])
    create index(:signaling_sessions, [:room_id, :from_user_id, :to_user_id])
  end
end
