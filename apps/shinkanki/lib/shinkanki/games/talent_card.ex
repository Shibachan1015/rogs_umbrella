defmodule Shinkanki.Games.TalentCard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @categories ~w(forest culture social akasha universal)

  schema "talent_cards" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :compatible_tags, {:array, :string}, default: []
    field :effect_type, :string
    field :effect_value, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(talent_card, attrs) do
    talent_card
    |> cast(attrs, [:name, :category, :description, :compatible_tags, :effect_type, :effect_value])
    |> validate_required([:name, :category, :description])
    |> validate_inclusion(:category, @categories)
  end

  @doc """
  タレントカードがアクションカードと互換性があるかチェック
  """
  def compatible_with?(%__MODULE__{compatible_tags: tags}, action_card_category) do
    action_card_category in tags or "universal" in tags
  end

  @doc """
  タレントの効果を適用
  effect_type:
    - "bonus": 効果値分のボーナスをカードカテゴリに追加
    - "cost_reduction": Akashaコストを削減
    - "extra_effect": 追加効果（全カテゴリに+1）
  """
  def apply_effect(%__MODULE__{effect_type: "bonus", effect_value: value, category: category}, effects, action_category) do
    # 同じカテゴリの場合は効果値を追加、そうでなければ半分
    bonus = if category == action_category, do: value, else: div(value, 2)

    effects
    |> Map.update(:forest, 0, fn v -> if action_category == "forest", do: v + bonus, else: v end)
    |> Map.update(:culture, 0, fn v -> if action_category == "culture", do: v + bonus, else: v end)
    |> Map.update(:social, 0, fn v -> if action_category == "social", do: v + bonus, else: v end)
  end

  def apply_effect(%__MODULE__{effect_type: "cost_reduction", effect_value: value}, costs, _action_category) do
    # Akashaコスト削減
    costs
    |> Map.update(:akasha, 0, &max(&1 - value, 0))
  end

  def apply_effect(%__MODULE__{effect_type: "extra_effect", effect_value: value}, effects, _action_category) do
    # 全カテゴリにボーナス
    effects
    |> Map.update(:forest, 0, &(&1 + value))
    |> Map.update(:culture, 0, &(&1 + value))
    |> Map.update(:social, 0, &(&1 + value))
  end

  def apply_effect(%__MODULE__{}, effects, _action_category), do: effects

  # 後方互換性のため2引数版も残す
  def apply_effect(talent, effects) do
    apply_effect(talent, effects, nil)
  end
end
