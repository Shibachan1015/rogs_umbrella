defmodule RogsComm.Repo.Migrations.AddRoomDeletionFields do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      # ホストのユーザーID
      add :host_id, :binary_id

      # 最終アクティビティ時刻
      add :last_activity_at, :utc_datetime

      # 削除提案時刻（nilなら提案なし）
      add :deletion_proposed_at, :utc_datetime

      # 削除投票（user_idの配列）
      add :deletion_votes, {:array, :binary_id}, default: []

      # 現在の参加者数（Presenceから更新）
      add :current_participants, :integer, default: 0
    end

    # 自動削除用のインデックス
    create index(:rooms, [:last_activity_at])
    create index(:rooms, [:current_participants])
  end
end
