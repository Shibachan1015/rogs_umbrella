defmodule Shinkanki.Repo.Migrations.CreateTalentCards do
  use Ecto.Migration

  def change do
    create table(:talent_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :category, :string, null: false
      add :description, :text
      add :compatible_tags, {:array, :string}, default: []
      add :effect_type, :string
      add :effect_value, :integer, default: 1

      timestamps()
    end

    create index(:talent_cards, [:category])
  end
end
