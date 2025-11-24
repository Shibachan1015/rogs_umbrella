defmodule RogsComm.Signaling.SignalingSession do
  @moduledoc """
  Signaling session entity for tracking WebRTC signaling events.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "signaling_sessions" do
    field :from_user_id, :binary_id
    field :to_user_id, :binary_id
    field :event_type, :string
    field :payload, :map
    field :created_at, :utc_datetime
    belongs_to :room, RogsComm.Rooms.Room

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(signaling_session, attrs) do
    signaling_session
    |> cast(attrs, [:room_id, :from_user_id, :to_user_id, :event_type, :payload, :created_at])
    |> validate_required([:room_id, :from_user_id, :event_type, :payload, :created_at])
    |> validate_inclusion(:event_type, ~w(offer answer ice-candidate peer-ready))
  end
end

