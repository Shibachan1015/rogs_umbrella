defmodule RogsComm.Repo.Migrations.AddCompositeIndexesToMessages do
  use Ecto.Migration

  def up do
    # Composite index for room_id + inserted_at (most common query pattern)
    # This optimizes list_messages and list_messages_before queries
    create index(:messages, [:room_id, :inserted_at])

    # Composite index for room_id + is_deleted (for filtering deleted messages)
    # This optimizes queries that filter by room_id and is_deleted
    create index(:messages, [:room_id, :is_deleted])

    # Partial index for non-deleted messages in a room (PostgreSQL specific optimization)
    # This can significantly improve performance when most messages are not deleted
    # Note: This uses a WHERE clause, which is PostgreSQL-specific
    # For other databases, we'll skip this index
    if System.get_env("DATABASE_URL") =~ "postgres" do
      execute("""
      CREATE INDEX IF NOT EXISTS messages_room_id_inserted_at_not_deleted_idx
      ON messages(room_id, inserted_at DESC)
      WHERE is_deleted = false
      """)
    end
  end

  def down do
    drop index(:messages, [:room_id, :inserted_at])
    drop index(:messages, [:room_id, :is_deleted])

    if System.get_env("DATABASE_URL") =~ "postgres" do
      execute("DROP INDEX IF EXISTS messages_room_id_inserted_at_not_deleted_idx")
    end
  end
end

