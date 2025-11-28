defmodule RogsIdentity.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # プロフィール
      add :avatar, :string, default: "🎮"
      add :bio, :string

      # ゲーム統計
      add :games_played, :integer, default: 0
      add :games_won, :integer, default: 0
    end
  end
end
