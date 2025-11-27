defmodule Shinkanki.Repo.Migrations.CreateEventCards do
  use Ecto.Migration

  def change do
    create table(:event_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :effect_forest, :integer, default: 0
      add :effect_culture, :integer, default: 0
      add :effect_social, :integer, default: 0
      add :effect_akasha, :integer, default: 0
      add :description, :text
      add :has_choice, :boolean, default: false
      add :choice_a_text, :string
      add :choice_a_effects, :map
      add :choice_b_text, :string
      add :choice_b_effects, :map

      timestamps()
    end

    create index(:event_cards, [:type])
  end
end
