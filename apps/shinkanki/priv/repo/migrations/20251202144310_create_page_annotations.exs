defmodule Shinkanki.Repo.Migrations.CreatePageAnnotations do
  use Ecto.Migration

  def change do
    create table(:page_annotations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :page_path, :string, null: false
      add :section_id, :string, null: false
      add :content, :text, null: false

      timestamps()
    end

    create index(:page_annotations, [:user_id])
    create index(:page_annotations, [:page_path, :section_id])
  end
end
