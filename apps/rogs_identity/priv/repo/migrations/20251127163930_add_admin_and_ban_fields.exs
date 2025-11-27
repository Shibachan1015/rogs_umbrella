defmodule RogsIdentity.Repo.Migrations.AddAdminAndBanFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # 管理者フラグ
      add :is_admin, :boolean, default: false, null: false

      # BAN情報
      add :banned_at, :utc_datetime
      add :banned_reason, :string
      add :banned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    # 管理者一覧取得用インデックス
    create index(:users, [:is_admin])
    create index(:users, [:banned_at])
  end
end
