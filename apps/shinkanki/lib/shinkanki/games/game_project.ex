defmodule Shinkanki.Games.GameProject do
  @moduledoc """
  ゲームセッション内のアクティブプロジェクト
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(active completed failed)

  schema "game_projects" do
    field :started_turn, :integer
    field :status, :string, default: "active"
    field :completed_turn, :integer

    belongs_to :game_session, Shinkanki.Games.GameSession
    belongs_to :project_template, Shinkanki.Games.ProjectTemplate

    has_many :project_participations, Shinkanki.Games.ProjectParticipation

    timestamps()
  end

  @doc false
  def changeset(game_project, attrs) do
    game_project
    |> cast(attrs, [:game_session_id, :project_template_id, :started_turn, :status, :completed_turn])
    |> validate_required([:game_session_id, :project_template_id, :started_turn])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:game_session_id)
    |> foreign_key_constraint(:project_template_id)
  end

  @doc """
  参加者数を取得
  """
  def participant_count(%__MODULE__{project_participations: participations}) when is_list(participations) do
    participations
    |> Enum.map(& &1.player_id)
    |> Enum.uniq()
    |> length()
  end

  def participant_count(_), do: 0

  @doc """
  プロジェクトがアクティブかどうか
  """
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(_), do: false

  @doc """
  プロジェクトが完成しているかどうか
  """
  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(_), do: false
end
