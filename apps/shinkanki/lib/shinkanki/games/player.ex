defmodule Shinkanki.Games.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(forest_guardian heritage_weaver community_keeper akasha_architect)

  schema "players" do
    field :akasha, :integer
    field :role, :string
    field :player_order, :integer

    belongs_to :game_session, Shinkanki.Games.GameSession
    field :user_id, :binary_id

    has_many :game_actions, Shinkanki.Games.GameAction
    has_many :project_participations, Shinkanki.Games.ProjectParticipation

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:akasha, :role, :player_order, :game_session_id, :user_id])
    |> validate_required([:akasha, :role, :player_order, :game_session_id])
    |> validate_number(:akasha, greater_than_or_equal_to: 0)
    |> validate_number(:player_order, greater_than_or_equal_to: 1, less_than_or_equal_to: 4)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:game_session_id, :player_order])
  end

  @doc """
  役割に応じたボーナスを取得
  """
  def role_bonus(role, category) do
    case {role, category} do
      {"forest_guardian", "forest"} -> 1
      {"heritage_weaver", "culture"} -> 1
      {"community_keeper", "social"} -> 1
      {"akasha_architect", "akasha"} -> 1
      _ -> 0
    end
  end

  @doc """
  Akasha減衰を適用（10%）
  """
  def apply_demurrage(%__MODULE__{akasha: akasha} = player) do
    demurrage_amount = div(akasha, 10)
    {player, demurrage_amount}
  end
end
