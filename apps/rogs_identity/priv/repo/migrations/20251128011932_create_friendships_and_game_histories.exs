defmodule RogsIdentity.Repo.Migrations.CreateFriendshipsAndGameHistories do
  use Ecto.Migration

  def change do
    # フレンド関係テーブル
    create table(:friendships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :requester_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :addressee_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :status, :string, default: "pending", null: false

      timestamps()
    end

    create index(:friendships, [:requester_id])
    create index(:friendships, [:addressee_id])
    create unique_index(:friendships, [:requester_id, :addressee_id])

    # ゲーム履歴テーブル
    create table(:game_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :played_with_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :room_id, :binary_id, null: false
      add :played_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:game_histories, [:user_id])
    create index(:game_histories, [:played_with_id])
    create index(:game_histories, [:user_id, :played_at])
  end
end
