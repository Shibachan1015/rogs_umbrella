defmodule Shinkanki.Games.ActionCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @categories ~w(forest culture social akasha)

  schema "action_cards" do
    field :name, :string
    field :category, :string
    field :effect_forest, :integer, default: 0
    field :effect_culture, :integer, default: 0
    field :effect_social, :integer, default: 0
    field :effect_akasha, :integer, default: 0
    field :cost_forest, :integer, default: 0
    field :cost_culture, :integer, default: 0
    field :cost_social, :integer, default: 0
    field :cost_akasha, :integer, default: 0
    field :description, :string
    field :special_effect, :string

    timestamps()
  end

  @doc false
  def changeset(action_card, attrs) do
    action_card
    |> cast(attrs, [
      :name,
      :category,
      :effect_forest,
      :effect_culture,
      :effect_social,
      :effect_akasha,
      :cost_forest,
      :cost_culture,
      :cost_social,
      :cost_akasha,
      :description,
      :special_effect
    ])
    |> validate_required([:name, :category])
    |> validate_inclusion(:category, @categories)
  end

  @doc """
  カードの効果を適用
  """
  def apply_effects(%__MODULE__{} = card, _game_session, player) do
    role_bonus = Shinkanki.Games.Player.role_bonus(player.role, card.category)

    %{
      forest: card.effect_forest + role_bonus,
      culture: card.effect_culture + role_bonus,
      social: card.effect_social + role_bonus,
      akasha: card.effect_akasha
    }
  end

  @doc """
  コストをチェック
  """
  def check_costs(%__MODULE__{} = card, game_session, player) do
    can_pay_forest = game_session.forest >= card.cost_forest
    can_pay_culture = game_session.culture >= card.cost_culture
    can_pay_social = game_session.social >= card.cost_social
    can_pay_akasha = player.akasha >= card.cost_akasha

    can_pay_forest and can_pay_culture and can_pay_social and can_pay_akasha
  end
end
