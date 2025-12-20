defmodule Shinkanki.Games.GameProject do
  @moduledoc """
  ゲームセッション内のアクティブプロジェクト
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Shinkanki.Games.{GameSession, ProjectTemplate, ProjectParticipation}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          started_turn: pos_integer(),
          status: String.t(),
          completed_turn: pos_integer() | nil,
          game_session_id: binary() | nil,
          game_session: GameSession.t() | Ecto.Association.NotLoaded.t() | nil,
          project_template_id: binary() | nil,
          project_template: ProjectTemplate.t() | Ecto.Association.NotLoaded.t() | nil,
          project_participations: [ProjectParticipation.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

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
    |> cast(attrs, [
      :game_session_id,
      :project_template_id,
      :started_turn,
      :status,
      :completed_turn
    ])
    |> validate_required([:game_session_id, :project_template_id, :started_turn])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:game_session_id)
    |> foreign_key_constraint(:project_template_id)
  end

  @doc """
  参加者数を取得
  """
  def participant_count(%__MODULE__{project_participations: participations})
      when is_list(participations) do
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
