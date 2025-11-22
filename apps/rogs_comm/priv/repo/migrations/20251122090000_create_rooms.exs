defmodule RogsComm.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :topic, :text
      add :is_private, :boolean, null: false, default: false
      add :max_participants, :integer, null: false, default: 8

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rooms, :slug)
    create index(:rooms, [:inserted_at])
  end
end
