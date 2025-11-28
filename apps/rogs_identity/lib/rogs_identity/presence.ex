defmodule RogsIdentity.Presence do
  @moduledoc """
  ユーザーのオンライン状態を追跡するPresenceモジュール
  """
  use Phoenix.Presence,
    otp_app: :rogs_identity,
    pubsub_server: RogsIdentity.PubSub

  alias RogsIdentity.Accounts.User

  @presence_topic "users:presence"

  @doc """
  ユーザーのオンライン状態をトラッキング開始
  """
  def track_user(%User{} = user) do
    track(self(), @presence_topic, user.id, %{
      user_id: user.id,
      name: User.display_name(user),
      avatar: User.avatar(user),
      online_at: DateTime.utc_now() |> DateTime.to_unix()
    })
  end

  def track_user(user_id, name, avatar) when is_binary(user_id) do
    track(self(), @presence_topic, user_id, %{
      user_id: user_id,
      name: name,
      avatar: avatar,
      online_at: DateTime.utc_now() |> DateTime.to_unix()
    })
  end

  @doc """
  ユーザーのオンライン状態を更新
  """
  def update_user(user_id, meta) when is_binary(user_id) do
    update(self(), @presence_topic, user_id, fn existing_meta ->
      Map.merge(existing_meta, meta)
    end)
  end

  @doc """
  Presenceトピックを購読
  """
  def subscribe do
    Phoenix.PubSub.subscribe(RogsIdentity.PubSub, @presence_topic)
  end

  @doc """
  オンラインユーザー一覧を取得
  """
  def list_online_users do
    list(@presence_topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      Map.put(meta, :user_id, user_id)
    end)
  end

  @doc """
  特定のユーザーがオンラインか確認
  """
  def online?(user_id) when is_binary(user_id) do
    list(@presence_topic)
    |> Map.has_key?(user_id)
  end

  @doc """
  オンラインのフレンドIDリストを取得
  """
  def online_friend_ids(friend_ids) when is_list(friend_ids) do
    online_ids = list(@presence_topic) |> Map.keys() |> MapSet.new()
    friend_set = MapSet.new(friend_ids)
    MapSet.intersection(online_ids, friend_set) |> MapSet.to_list()
  end

  @doc """
  Presenceトピック名を取得
  """
  def topic, do: @presence_topic
end
