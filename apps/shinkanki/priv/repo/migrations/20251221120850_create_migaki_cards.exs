defmodule Shinkanki.Repo.Migrations.CreateMigakiCards do
  use Ecto.Migration

  def change do
    create table(:migaki_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :category, :string
      add :description, :text
      add :cost_akasha, :integer, default: 0
      add :effect_forest, :integer, default: 0
      add :effect_culture, :integer, default: 0
      add :effect_social, :integer, default: 0
      add :effect_jaki, :integer, default: 0
      add :special_effect, :text
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    create index(:migaki_cards, [:category])
    create unique_index(:migaki_cards, [:name])
  end
end
