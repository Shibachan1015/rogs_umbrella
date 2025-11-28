defmodule Shinkanki.Repo.Migrations.CreatePlayerTalents do
  use Ecto.Migration

  def change do
    create table(:player_talents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :player_id, references(:players, on_delete: :delete_all, type: :binary_id), null: false
      add :talent_card_id, references(:talent_cards, on_delete: :delete_all, type: :binary_id), null: false
      add :is_used, :boolean, default: false

      timestamps()
    end

    create index(:player_talents, [:player_id])
    create index(:player_talents, [:talent_card_id])
    create unique_index(:player_talents, [:player_id, :talent_card_id])
  end
end
