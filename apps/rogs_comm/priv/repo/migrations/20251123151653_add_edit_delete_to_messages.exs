defmodule RogsComm.Repo.Migrations.AddEditDeleteToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_deleted, :boolean, default: false, null: false
      add :edited_at, :utc_datetime
    end

    create index(:messages, [:is_deleted])
  end
end
