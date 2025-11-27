defmodule Shinkanki.Games.TurnState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @phases ~w(event action dao end)

  schema "turn_states" do
    field :turn_number, :integer
    field :phase, :string, default: "event"
    field :available_cards, {:array, :binary_id}, default: []
    field :current_event_id, :binary_id
    field :event_choice, :string

    belongs_to :game_session, Shinkanki.Games.GameSession

    timestamps()
  end

  @doc false
  def changeset(turn_state, attrs) do
    turn_state
    |> cast(attrs, [
      :turn_number,
      :phase,
      :available_cards,
      :current_event_id,
      :event_choice,
      :game_session_id
    ])
    |> validate_required([:turn_number, :phase, :game_session_id])
    |> validate_inclusion(:phase, @phases)
    |> unique_constraint([:game_session_id, :turn_number])
  end

  @doc """
  次のフェーズへ進む
  """
  def next_phase("event"), do: "action"
  def next_phase("action"), do: "dao"
  def next_phase("dao"), do: "end"
  def next_phase("end"), do: "event"
end
