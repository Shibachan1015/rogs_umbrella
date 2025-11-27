defmodule Shinkanki.Repo.Migrations.CreateCollaborativeProjects do
  use Ecto.Migration

  def change do
    # プロジェクトテンプレート（マスターデータ）
    create table(:project_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :required_participants, :integer, default: 4
      add :required_turns, :integer
      add :required_dao_pool, :integer
      add :effect_forest, :integer, default: 0
      add :effect_culture, :integer, default: 0
      add :effect_social, :integer, default: 0
      add :effect_akasha, :integer, default: 0
      add :permanent_effect, :string
      add :permanent_effect_value, :integer

      timestamps()
    end

    # ゲーム内のアクティブプロジェクト
    create table(:game_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_session_id, references(:game_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :project_template_id, references(:project_templates, type: :binary_id, on_delete: :restrict), null: false
      add :started_turn, :integer, null: false
      add :status, :string, default: "active"
      add :completed_turn, :integer

      timestamps()
    end

    create index(:game_projects, [:game_session_id])
    create index(:game_projects, [:project_template_id])

    # プレイヤーのプロジェクト参加記録
    create table(:project_participations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_project_id, references(:game_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :player_id, references(:players, type: :binary_id, on_delete: :delete_all), null: false
      add :turn, :integer, null: false

      timestamps()
    end

    create index(:project_participations, [:game_project_id])
    create index(:project_participations, [:player_id])
    create unique_index(:project_participations, [:game_project_id, :player_id, :turn])
  end
end
