defmodule RogsIdentity.Friends.Friendship do
  @moduledoc """
  フレンド関係を管理するスキーマ
  - pending: 申請中
  - accepted: フレンド成立
  - rejected: 拒否
  - blocked: ブロック
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RogsIdentity.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:pending, :accepted, :rejected, :blocked]

  schema "friendships" do
    # 申請者
    belongs_to :requester, User
    # 受信者
    belongs_to :addressee, User

    field :status, Ecto.Enum, values: @statuses, default: :pending

    timestamps()
  end

  @doc false
  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:requester_id, :addressee_id, :status])
    |> validate_required([:requester_id, :addressee_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_not_self_friend()
    |> unique_constraint([:requester_id, :addressee_id],
      name: :friendships_requester_id_addressee_id_index,
      message: "すでにフレンド申請済みです"
    )
  end

  defp validate_not_self_friend(changeset) do
    requester_id = get_field(changeset, :requester_id)
    addressee_id = get_field(changeset, :addressee_id)

    if requester_id == addressee_id do
      add_error(changeset, :addressee_id, "自分自身にはフレンド申請できません")
    else
      changeset
    end
  end
end

