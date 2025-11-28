defmodule RogsIdentity.Messages.RoomInvitation do
  @moduledoc """
  ルームへの招待
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RogsIdentity.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:pending, :accepted, :declined, :expired]

  schema "room_invitations" do
    belongs_to :sender, User
    belongs_to :receiver, User

    field :room_id, :binary_id
    field :room_name, :string
    field :room_slug, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :expires_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:sender_id, :receiver_id, :room_id, :room_name, :room_slug, :status, :expires_at])
    |> validate_required([:sender_id, :receiver_id, :room_id, :room_name, :room_slug])
    |> validate_inclusion(:status, @statuses)
    |> set_default_expiration()
  end

  defp set_default_expiration(changeset) do
    if get_field(changeset, :expires_at) do
      changeset
    else
      # デフォルトで10分後に期限切れ
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(10, :minute)
        |> DateTime.truncate(:second)

      put_change(changeset, :expires_at, expires_at)
    end
  end

  @doc """
  招待が期限切れかどうか
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
end

