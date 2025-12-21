defmodule RogsComm.Repo.Migrations.AddInviteCodeToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :invite_code, :string, size: 6
    end

    create unique_index(:rooms, [:invite_code])
  end
end
