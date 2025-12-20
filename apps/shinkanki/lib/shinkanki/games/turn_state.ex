defmodule Shinkanki.Games.TurnState do
  @moduledoc """
  Schema and functions for managing the state of a single turn within a game session, including current phase and available cards.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Shinkanki.Games.GameSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          turn_number: pos_integer(),
          phase: String.t(),
          available_cards: [binary()],
          current_event_id: binary() | nil,
          event_choice: String.t() | nil,
          game_session_id: binary() | nil,
          game_session: GameSession.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  # フェーズ順序（shinkanki_rules.xmlに準拠）:
  # hitoyo(人代) -> kami_hakari(神議り) -> itonami(営み) -> kokyu(呼吸) -> musuhi(結び) -> toshiokuri(年送り)
  @phases ~w(hitoyo kami_hakari itonami kokyu musuhi toshiokuri)
  # 後方互換性のための古いフェーズ名
  @legacy_phases ~w(event action breathing end)
  @all_phases @phases ++ @legacy_phases

  schema "turn_states" do
    field :turn_number, :integer
    field :phase, :string, default: "hitoyo"
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
    |> validate_inclusion(:phase, @all_phases)
    |> unique_constraint([:game_session_id, :turn_number])
  end

  @doc """
  次のフェーズへ進む
  hitoyo -> kami_hakari -> itonami -> kokyu -> musuhi -> toshiokuri -> (次のターン)
  """
  def next_phase("hitoyo"), do: "kami_hakari"
  def next_phase("kami_hakari"), do: "itonami"
  def next_phase("itonami"), do: "kokyu"
  def next_phase("kokyu"), do: "musuhi"
  def next_phase("musuhi"), do: "toshiokuri"
  def next_phase("toshiokuri"), do: "hitoyo"
  # 後方互換性のため古いフェーズ名もサポート
  def next_phase("event"), do: "itonami"
  def next_phase("action"), do: "kokyu"
  def next_phase("breathing"), do: "musuhi"
  def next_phase("end"), do: "hitoyo"
  def next_phase(_), do: "hitoyo"

  @doc """
  フェーズ名を日本語で取得
  """
  def phase_name("hitoyo"), do: "人代"
  def phase_name("kami_hakari"), do: "神議り"
  def phase_name("itonami"), do: "営み"
  def phase_name("kokyu"), do: "呼吸"
  def phase_name("musuhi"), do: "結び"
  def phase_name("toshiokuri"), do: "年送り"
  # 後方互換性のため古いフェーズ名もサポート
  def phase_name("event"), do: "人代"
  def phase_name("action"), do: "営み"
  def phase_name("breathing"), do: "呼吸"
  def phase_name("end"), do: "年送り"
  def phase_name(_), do: "待機"
end
