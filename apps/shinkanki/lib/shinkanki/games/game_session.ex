defmodule Shinkanki.Games.GameSession do
  @moduledoc """
  Schema and functions for managing the overall state of a game session, including parameters, players, and current phase.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Shinkanki.Games.{Player, GameProject, GameAction, TurnState}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          turn: pos_integer(),
          forest: non_neg_integer(),
          culture: non_neg_integer(),
          social: non_neg_integer(),
          life_index: integer(),
          dao_pool: non_neg_integer(),
          status: String.t(),
          seed: String.t() | nil,
          room_id: binary() | nil,
          evil_pool: non_neg_integer(),
          evil_threshold: pos_integer(),
          orochi_level: non_neg_integer(),
          current_policy: String.t() | nil,
          players: [Player.t()] | Ecto.Association.NotLoaded.t(),
          game_projects: [GameProject.t()] | Ecto.Association.NotLoaded.t(),
          game_actions: [GameAction.t()] | Ecto.Association.NotLoaded.t(),
          turn_states: [TurnState.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @policies ~w(forest culture community purify)

  schema "game_sessions" do
    field :turn, :integer, default: 1
    field :forest, :integer
    field :culture, :integer
    field :social, :integer
    field :life_index, :integer
    field :dao_pool, :integer, default: 0
    field :status, :string, default: "active"
    field :seed, :string
    field :room_id, :binary_id

    # 邪気・オロチシステム
    field :evil_pool, :integer, default: 0
    field :evil_threshold, :integer, default: 3
    field :orochi_level, :integer, default: 1
    # 神議りで決めた今年の方針
    field :current_policy, :string

    has_many :players, Shinkanki.Games.Player
    has_many :game_projects, Shinkanki.Games.GameProject
    has_many :game_actions, Shinkanki.Games.GameAction
    has_many :turn_states, Shinkanki.Games.TurnState

    timestamps()
  end

  @doc false
  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [
      :turn,
      :forest,
      :culture,
      :social,
      :life_index,
      :dao_pool,
      :status,
      :seed,
      :room_id,
      :evil_pool,
      :evil_threshold,
      :orochi_level,
      :current_policy
    ])
    |> validate_required([:forest, :culture, :social, :life_index])
    |> validate_number(:forest, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:culture, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:social, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:turn, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> validate_number(:evil_pool, greater_than_or_equal_to: 0)
    |> validate_number(:orochi_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 3)
    |> validate_inclusion(:status, ["active", "completed", "failed"])
    |> validate_number(:life_index, greater_than_or_equal_to: 0, less_than_or_equal_to: 300)
    |> validate_inclusion(:current_policy, @policies ++ [nil])
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
