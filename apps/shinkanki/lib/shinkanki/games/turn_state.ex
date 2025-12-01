defmodule Shinkanki.Games.TurnState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # フェーズ順序: kami_hakari(神議り) -> event -> action -> breathing(呼吸) -> musuhi(結び) -> end
  @phases ~w(kami_hakari event action breathing musuhi end)

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
  kami_hakari -> event -> action -> breathing -> musuhi -> end -> (次のターン)
  """
  def next_phase("kami_hakari"), do: "event"
  def next_phase("event"), do: "action"
  def next_phase("action"), do: "breathing"
  def next_phase("breathing"), do: "musuhi"
  def next_phase("musuhi"), do: "end"
  def next_phase("end"), do: "kami_hakari"

  @doc """
  フェーズ名を日本語で取得
  """
  def phase_name("kami_hakari"), do: "神議り"
  def phase_name("event"), do: "イベント"
  def phase_name("action"), do: "営み"
  def phase_name("breathing"), do: "呼吸"
  def phase_name("musuhi"), do: "結び"
  def phase_name("end"), do: "年の終わり"
  def phase_name(_), do: "待機"
end
