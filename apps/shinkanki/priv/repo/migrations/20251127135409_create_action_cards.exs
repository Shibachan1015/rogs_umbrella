defmodule Shinkanki.Repo.Migrations.CreateActionCards do
  use Ecto.Migration

  def change do
    create table(:action_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :category, :string, null: false
      add :effect_forest, :integer, default: 0
      add :effect_culture, :integer, default: 0
      add :effect_social, :integer, default: 0
      add :effect_akasha, :integer, default: 0
      add :cost_forest, :integer, default: 0
      add :cost_culture, :integer, default: 0
      add :cost_social, :integer, default: 0
      add :cost_akasha, :integer, default: 0
      add :description, :text
      add :special_effect, :string

      timestamps()
    end

    create index(:action_cards, [:category])
  end
end
