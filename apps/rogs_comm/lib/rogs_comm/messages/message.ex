defmodule RogsComm.Messages.Message do
  @moduledoc """
  Message entity representing a chat message in a room.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :user_id, :binary_id
    field :user_email, :string
    field :is_deleted, :boolean, default: false
    field :edited_at, :utc_datetime
    belongs_to :room, RogsComm.Rooms.Room

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :user_id, :user_email, :room_id])
    |> validate_required([:content, :user_id, :user_email, :room_id])
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_length(:user_email, max: 160)
  end
end
