defmodule RogsIdentity.Friends.GameHistory do
  @moduledoc """
  ゲーム履歴を管理するスキーマ
  どのゲームで誰と一緒に遊んだかを記録
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RogsIdentity.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_histories" do
    belongs_to :user, User
    belongs_to :played_with, User

    # ゲームのルームID（参照用）
    field :room_id, :binary_id
    # ゲーム終了時刻
    field :played_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(game_history, attrs) do
    game_history
    |> cast(attrs, [:user_id, :played_with_id, :room_id, :played_at])
    |> validate_required([:user_id, :played_with_id, :room_id, :played_at])
  end
end

