defmodule Shinkanki.Games.OkamiCard do
  @moduledoc """
  大神様カード（Okami Card）のスキーマ
  神々の祝福を表すカード。
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "okami_cards" do
    field :name, :string
    field :deity_name, :string
    field :description, :string
    field :effect_forest, :integer, default: 0
    field :effect_culture, :integer, default: 0
    field :effect_social, :integer, default: 0
    field :effect_akasha, :integer, default: 0
    field :special_effect, :string
    field :image_url, :string

    timestamps()
  end

  @doc false
  def changeset(okami_card, attrs) do
    okami_card
    |> cast(attrs, [
      :name,
      :deity_name,
      :description,
      :effect_forest,
      :effect_culture,
      :effect_social,
      :effect_akasha,
      :special_effect,
      :image_url
    ])
    |> validate_required([:name])
  end
end
