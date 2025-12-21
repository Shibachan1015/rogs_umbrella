defmodule Shinkanki.Repo.Migrations.CreateRulebookSections do
  use Ecto.Migration

  def change do
    # 現在のルールブックセクション
    create table(:rulebook_sections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :section_id, :string, null: false
      add :title, :string, null: false
      add :content, :text, null: false
      add :order_index, :integer, null: false, default: 0
      add :updated_by, :binary_id
      add :editor_name, :string
      add :version, :integer, null: false, default: 1

      timestamps()
    end

    create unique_index(:rulebook_sections, [:section_id])
    create index(:rulebook_sections, [:order_index])

    # 編集履歴（世代）
    create table(:rulebook_section_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rulebook_section_id, references(:rulebook_sections, type: :binary_id, on_delete: :delete_all), null: false
      add :section_id, :string, null: false
      add :title, :string, null: false
      add :content, :text, null: false
      add :version, :integer, null: false
      add :updated_by, :binary_id
      add :editor_name, :string

      timestamps(updated_at: false)
    end

    create index(:rulebook_section_histories, [:rulebook_section_id])
    create index(:rulebook_section_histories, [:section_id, :version])
  end
end
