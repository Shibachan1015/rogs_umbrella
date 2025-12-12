defmodule RogsIdentity.Repo.Migrations.AddOauthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider, :string
      add :provider_id, :string
      add :avatar_url, :string
    end

    # provider_idでの検索用インデックス
    create index(:users, [:provider, :provider_id])
  end
end
