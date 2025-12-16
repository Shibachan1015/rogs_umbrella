defmodule RogsComm.Repo.Migrations.AddCategoryToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :category, :string, default: "game", null: false
    end

    create index(:rooms, [:category])
  end
end
