defmodule Shinkanki.Games.PlayerTalent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_talents" do
    field :is_used, :boolean, default: false

    belongs_to :player, Shinkanki.Games.Player
    belongs_to :talent_card, Shinkanki.Games.TalentCard

    timestamps()
  end

  @doc false
  def changeset(player_talent, attrs) do
    player_talent
    |> cast(attrs, [:player_id, :talent_card_id, :is_used])
    |> validate_required([:player_id, :talent_card_id])
    |> unique_constraint([:player_id, :talent_card_id])
  end

  @doc """
  タレントを使用済みにマーク
  """
  def mark_as_used(player_talent) do
    player_talent
    |> change(%{is_used: true})
  end
end
