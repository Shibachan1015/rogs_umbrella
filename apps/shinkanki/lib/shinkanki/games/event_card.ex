defmodule Shinkanki.Games.EventCard do
  @moduledoc """
  Schema and functions for event cards used in the game, including effects and choice handling.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: binary() | nil,
          name: String.t(),
          type: String.t(),
          effect_forest: integer(),
          effect_culture: integer(),
          effect_social: integer(),
          effect_akasha: integer(),
          description: String.t() | nil,
          has_choice: boolean(),
          choice_a_text: String.t() | nil,
          choice_a_effects: map() | nil,
          choice_b_text: String.t() | nil,
          choice_b_effects: map() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @types ~w(positive negative choice)

  schema "event_cards" do
    field :name, :string
    field :type, :string
    field :effect_forest, :integer, default: 0
    field :effect_culture, :integer, default: 0
    field :effect_social, :integer, default: 0
    field :effect_akasha, :integer, default: 0
    field :description, :string
    field :has_choice, :boolean, default: false
    field :choice_a_text, :string
    field :choice_a_effects, :map
    field :choice_b_text, :string
    field :choice_b_effects, :map
    field :image_url, :string

    timestamps()
  end

  @doc false
  def changeset(event_card, attrs) do
    event_card
    |> cast(attrs, [
      :name,
      :type,
      :effect_forest,
      :effect_culture,
      :effect_social,
      :effect_akasha,
      :description,
      :has_choice,
      :choice_a_text,
      :choice_a_effects,
      :choice_b_text,
      :choice_b_effects,
      :image_url
    ])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @types)
  end

  @doc """
  イベントの効果を取得
  choiceが指定されていない場合は、デフォルト効果を返す
  """
  def get_effects(%__MODULE__{has_choice: false} = event) do
    %{
      forest: event.effect_forest || 0,
      culture: event.effect_culture || 0,
      social: event.effect_social || 0,
      akasha: event.effect_akasha || 0
    }
  end

  def get_effects(%__MODULE__{has_choice: true} = event) do
    # 選択肢がある場合は、デフォルトでchoice_aの効果を返す
    # 実際の選択はchoiceパラメータ付きのget_effects/2を使う
    event.choice_a_effects ||
      %{
        forest: 0,
        culture: 0,
        social: 0,
        akasha: 0
      }
  end

  def get_effects(%__MODULE__{has_choice: true} = event, choice) do
    case choice do
      :choice_a ->
        event.choice_a_effects ||
          %{
            forest: 0,
            culture: 0,
            social: 0,
            akasha: 0
          }

      :choice_b ->
        event.choice_b_effects ||
          %{
            forest: 0,
            culture: 0,
            social: 0,
            akasha: 0
          }

      _ ->
        %{
          forest: 0,
          culture: 0,
          social: 0,
          akasha: 0
        }
    end
  end
end
