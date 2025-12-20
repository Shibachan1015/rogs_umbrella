defmodule Shinkanki.Games.GameAction do
  @moduledoc """
  Schema for individual game actions performed by players within a game session.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Shinkanki.Games.{GameSession, Player, ActionCard}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          turn: pos_integer(),
          action_type: String.t(),
          details: map() | nil,
          game_session_id: binary() | nil,
          game_session: GameSession.t() | Ecto.Association.NotLoaded.t() | nil,
          player_id: binary() | nil,
          player: Player.t() | Ecto.Association.NotLoaded.t() | nil,
          action_card_id: binary() | nil,
          action_card: ActionCard.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @action_types ~w(play_card join_project dao_vote gift_akasha pass play_card_with_talents)

  schema "game_actions" do
    field :turn, :integer
    field :action_type, :string
    field :details, :map

    belongs_to :game_session, Shinkanki.Games.GameSession
    belongs_to :player, Shinkanki.Games.Player
    belongs_to :action_card, Shinkanki.Games.ActionCard

    timestamps()
  end

  @doc false
  def changeset(action, attrs) do
    action
    |> cast(attrs, [:turn, :action_type, :details, :game_session_id, :player_id, :action_card_id])
    |> validate_required([:turn, :action_type, :game_session_id])
    |> validate_inclusion(:action_type, @action_types)
  end
end
