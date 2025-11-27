defmodule Shinkanki.Games.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_sessions" do
    field :turn, :integer, default: 1
    field :forest, :integer
    field :culture, :integer
    field :social, :integer
    field :life_index, :integer
    field :dao_pool, :integer, default: 0
    field :status, :string, default: "active"
    field :seed, :string

    has_many :players, Shinkanki.Games.Player
    has_many :game_projects, Shinkanki.Games.GameProject
    has_many :game_actions, Shinkanki.Games.GameAction
    has_many :turn_states, Shinkanki.Games.TurnState

    timestamps()
  end

  @doc false
  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:turn, :forest, :culture, :social, :life_index, :dao_pool, :status, :seed])
    |> validate_required([:forest, :culture, :social, :life_index])
    |> validate_number(:forest, greater_than_or_equal_to: 0, less_than_or_equal_to: 20)
    |> validate_number(:culture, greater_than_or_equal_to: 0, less_than_or_equal_to: 20)
    |> validate_number(:social, greater_than_or_equal_to: 0, less_than_or_equal_to: 20)
    |> validate_number(:turn, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> validate_inclusion(:status, ["active", "completed", "failed"])
  end

  @doc """
  生命指数を計算
  """
  def calculate_life_index(%__MODULE__{} = game) do
    game.forest + game.culture + game.social
  end

  @doc """
  即時敗北条件のチェック
  """
  def check_immediate_loss?(%__MODULE__{} = game) do
    game.forest == 0 or game.culture == 0 or game.social == 0
  end

  @doc """
  エンディング判定
  """
  def get_ending(%__MODULE__{life_index: life_index}) when life_index >= 40, do: :gods_blessing
  def get_ending(%__MODULE__{life_index: life_index}) when life_index >= 30, do: :purification
  def get_ending(%__MODULE__{life_index: life_index}) when life_index >= 20, do: :fluctuation
  def get_ending(%__MODULE__{}), do: :gods_lament
end
