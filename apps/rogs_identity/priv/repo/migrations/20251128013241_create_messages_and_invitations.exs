defmodule RogsIdentity.Repo.Migrations.CreateMessagesAndInvitations do
  use Ecto.Migration

  def change do
    # ダイレクトメッセージテーブル
    create table(:direct_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :receiver_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :content, :text, null: false
      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:direct_messages, [:sender_id])
    create index(:direct_messages, [:receiver_id])
    create index(:direct_messages, [:receiver_id, :sender_id, :inserted_at])

    # ルーム招待テーブル
    create table(:room_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :receiver_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :room_id, :binary_id, null: false
      add :room_name, :string, null: false
      add :room_slug, :string, null: false
      add :status, :string, default: "pending", null: false
      add :expires_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:room_invitations, [:receiver_id, :status])
    create index(:room_invitations, [:expires_at])
  end
end
