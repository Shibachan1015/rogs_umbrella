defmodule RogsIdentity.Messages.DirectMessage do
  @moduledoc """
  フレンド間のダイレクトメッセージ
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RogsIdentity.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "direct_messages" do
    belongs_to :sender, User
    belongs_to :receiver, User

    field :content, :string
    field :read_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender_id, :receiver_id, :content, :read_at])
    |> validate_required([:sender_id, :receiver_id, :content])
    |> validate_length(:content, min: 1, max: 500, message: "は1〜500文字で入力してください")
    |> validate_not_self_message()
  end

  defp validate_not_self_message(changeset) do
    sender_id = get_field(changeset, :sender_id)
    receiver_id = get_field(changeset, :receiver_id)

    if sender_id == receiver_id do
      add_error(changeset, :receiver_id, "自分自身にはメッセージを送れません")
    else
      changeset
    end
  end
end
