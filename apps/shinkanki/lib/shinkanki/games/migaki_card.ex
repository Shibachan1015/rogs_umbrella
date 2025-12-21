defmodule Shinkanki.Games.MigakiCard do
  @moduledoc """
  磨きカード（Migaki Card）のスキーマ
  世界を「きれいにしていく」行動のカード。
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "migaki_cards" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :cost_akasha, :integer, default: 0
    field :effect_forest, :integer, default: 0
    field :effect_culture, :integer, default: 0
    field :effect_social, :integer, default: 0
    field :effect_jaki, :integer, default: 0
    field :special_effect, :string
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(migaki_card, attrs) do
    migaki_card
    |> cast(attrs, [
      :name,
      :category,
      :description,
      :cost_akasha,
      :effect_forest,
      :effect_culture,
      :effect_social,
      :effect_jaki,
      :special_effect,
      :tags
    ])
    |> validate_required([:name])
  end
end
