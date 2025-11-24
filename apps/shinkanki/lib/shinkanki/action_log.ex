defmodule Shinkanki.ActionLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "action_logs" do
    field :room_id, :string
    field :turn, :integer
    field :player_id, :string
    field :action, :string
    field :payload, :map

    timestamps()
  end

  @doc false
  def changeset(action_log, attrs) do
    action_log
    |> cast(attrs, [:room_id, :turn, :player_id, :action, :payload])
    |> validate_required([:room_id, :turn, :action])
  end
end
