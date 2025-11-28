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
    field :is_ai, :boolean, default: false
    field :ai_name, :string

    belongs_to :game_session, Shinkanki.Games.GameSession
    field :user_id, :binary_id

    has_many :game_actions, Shinkanki.Games.GameAction
    has_many :project_participations, Shinkanki.Games.ProjectParticipation
    has_many :player_talents, Shinkanki.Games.PlayerTalent
    has_many :talents, through: [:player_talents, :talent_card]

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:akasha, :role, :player_order, :game_session_id, :user_id, :is_ai, :ai_name])
    |> validate_required([:akasha, :role, :player_order, :game_session_id])
    |> validate_number(:akasha, greater_than_or_equal_to: 0)
    |> validate_number(:player_order, greater_than_or_equal_to: 1, less_than_or_equal_to: 4)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:game_session_id, :player_order])
  end

  @ai_names ~w(森の精霊 文化の守人 絆の使者 空環の賢者)

  @doc """
  AIプレイヤーを作成するための属性を生成
  """
  def ai_player_attrs(player_order, role) do
    ai_name = Enum.at(@ai_names, player_order - 1, "AI神#{player_order}")

    %{
      akasha: 10,
      role: role,
      player_order: player_order,
      is_ai: true,
      ai_name: ai_name,
      user_id: nil
    }
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
