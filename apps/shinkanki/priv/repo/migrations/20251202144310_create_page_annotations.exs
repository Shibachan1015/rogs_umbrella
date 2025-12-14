defmodule Shinkanki.Repo.Migrations.CreatePageAnnotations do
  use Ecto.Migration

  def change do
    create table(:page_annotations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # user_id is in rogs_identity database, so we use a plain column without FK constraint
      add :user_id, :binary_id, null: false
      add :page_path, :string, null: false
      add :section_id, :string, null: false
      add :content, :text, null: false

      timestamps()
    end

    create index(:page_annotations, [:user_id])
    create index(:page_annotations, [:page_path, :section_id])
  end
end
