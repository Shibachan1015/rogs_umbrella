defmodule Shinkanki.Repo.Migrations.AddRoomIdToGameSessions do
  use Ecto.Migration

  def change do
    alter table(:game_sessions) do
      add :room_id, :binary_id
    end

    create index(:game_sessions, [:room_id])
  end
end
