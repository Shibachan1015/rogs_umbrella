defmodule Shinkanki.Games.ProjectParticipation do
  @moduledoc """
  プレイヤーのプロジェクト参加記録
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Shinkanki.Games.{GameProject, Player}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          turn: pos_integer(),
          game_project_id: binary() | nil,
          game_project: GameProject.t() | Ecto.Association.NotLoaded.t() | nil,
          player_id: binary() | nil,
          player: Player.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "project_participations" do
    field :turn, :integer

    belongs_to :game_project, Shinkanki.Games.GameProject
    belongs_to :player, Shinkanki.Games.Player

    timestamps()
  end

  @doc false
  def changeset(participation, attrs) do
    participation
    |> cast(attrs, [:game_project_id, :player_id, :turn])
    |> validate_required([:game_project_id, :player_id, :turn])
    |> validate_number(:turn, greater_than: 0)
    |> foreign_key_constraint(:game_project_id)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:game_project_id, :player_id, :turn],
      name: :project_participations_game_project_id_player_id_turn_index
    )
  end
end
