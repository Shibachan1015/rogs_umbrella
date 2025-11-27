defmodule Shinkanki.Games.ProjectParticipation do
  @moduledoc """
  プレイヤーのプロジェクト参加記録
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

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
