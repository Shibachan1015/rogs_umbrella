defmodule RogsComm.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, :binary_id, null: false
      add :content, :text, null: false
      add :user_email, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:room_id])
    create index(:messages, [:user_id])
    create index(:messages, [:inserted_at])
  end
end
