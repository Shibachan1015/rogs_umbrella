defmodule Shinkanki.Repo.Migrations.AddOkamiCardsAndImages do
  use Ecto.Migration

  def change do
    # Create okami_cards table (大神様カード)
    create table(:okami_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :deity_name, :string
      add :description, :text
      add :effect_forest, :integer, default: 0
      add :effect_culture, :integer, default: 0
      add :effect_social, :integer, default: 0
      add :effect_akasha, :integer, default: 0
      add :special_effect, :text
      add :image_url, :string

      timestamps()
    end

    create unique_index(:okami_cards, [:name])

    # Add image_url to all existing card tables
    alter table(:action_cards) do
      add :image_url, :string
    end

    alter table(:event_cards) do
      add :image_url, :string
    end

    alter table(:talent_cards) do
      add :image_url, :string
    end

    alter table(:project_templates) do
      add :image_url, :string
    end

    alter table(:migaki_cards) do
      add :image_url, :string
    end
  end
end
