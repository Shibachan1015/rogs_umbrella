defmodule Shinkanki.Repo.Migrations.AddAiFieldsToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :is_ai, :boolean, default: false, null: false
      add :ai_name, :string
    end
  end
end
