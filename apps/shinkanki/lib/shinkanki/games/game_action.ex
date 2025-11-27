defmodule Shinkanki.Games.GameAction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @action_types ~w(play_card join_project dao_vote gift_akasha)

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
