defmodule RogsIdentity.Friends do
  @moduledoc """
  フレンド機能のコンテキスト
  - フレンド申請/承認/拒否/ブロック
  - フレンドリスト取得
  - 最近遊んだ人
  """

  import Ecto.Query, warn: false
  alias RogsIdentity.Repo
  alias RogsIdentity.Friends.{Friendship, GameHistory}
  alias RogsIdentity.Accounts.User

  # ============================================================
  # フレンド申請
  # ============================================================

  @doc """
  フレンド申請を送信
  """
  def send_friend_request(requester_id, addressee_id) do
    # すでに関係があるかチェック
    case get_friendship(requester_id, addressee_id) do
      nil ->
        %Friendship{}
        |> Friendship.changeset(%{
          requester_id: requester_id,
          addressee_id: addressee_id,
          status: :pending
        })
        |> Repo.insert()

      %Friendship{status: :rejected} = friendship ->
        # 以前拒否されていた場合は再申請可能
        friendship
        |> Friendship.changeset(%{status: :pending})
        |> Repo.update()

      %Friendship{status: :pending} ->
        {:error, :already_pending}

      %Friendship{status: :accepted} ->
        {:error, :already_friends}

      %Friendship{status: :blocked} ->
        {:error, :blocked}
    end
  end

  @doc """
  フレンド申請を承認
  """
  def accept_friend_request(friendship_id, addressee_id) do
    case Repo.get(Friendship, friendship_id) do
      nil ->
        {:error, :not_found}

      %Friendship{addressee_id: ^addressee_id, status: :pending} = friendship ->
        friendship
        |> Friendship.changeset(%{status: :accepted})
        |> Repo.update()

      %Friendship{addressee_id: ^addressee_id} ->
        {:error, :not_pending}

      _ ->
        {:error, :not_authorized}
    end
  end

  @doc """
  フレンド申請を拒否
  """
  def reject_friend_request(friendship_id, addressee_id) do
    case Repo.get(Friendship, friendship_id) do
      nil ->
        {:error, :not_found}

      %Friendship{addressee_id: ^addressee_id, status: :pending} = friendship ->
        friendship
        |> Friendship.changeset(%{status: :rejected})
        |> Repo.update()

      %Friendship{addressee_id: ^addressee_id} ->
        {:error, :not_pending}

      _ ->
        {:error, :not_authorized}
    end
  end

  @doc """
  ユーザーをブロック
  """
  def block_user(blocker_id, blocked_id) do
    case get_friendship(blocker_id, blocked_id) do
      nil ->
        %Friendship{}
        |> Friendship.changeset(%{
          requester_id: blocker_id,
          addressee_id: blocked_id,
          status: :blocked
        })
        |> Repo.insert()

      friendship ->
        friendship
        |> Friendship.changeset(%{status: :blocked})
        |> Repo.update()
    end
  end

  @doc """
  フレンドを解除
  """
  def remove_friend(user_id, friend_id) do
    case get_friendship(user_id, friend_id) do
      nil ->
        {:error, :not_found}

      friendship ->
        Repo.delete(friendship)
    end
  end

  # ============================================================
  # フレンドリスト取得
  # ============================================================

  @doc """
  フレンドリストを取得（承認済みのみ）
  """
  def list_friends(user_id) do
    from(f in Friendship,
      where: f.status == :accepted,
      where: f.requester_id == ^user_id or f.addressee_id == ^user_id,
      join: u in User,
      on:
        (f.requester_id == ^user_id and u.id == f.addressee_id) or
          (f.addressee_id == ^user_id and u.id == f.requester_id),
      select: %{
        id: u.id,
        name: u.name,
        email: u.email,
        avatar: u.avatar,
        games_played: u.games_played,
        games_won: u.games_won,
        friendship_id: f.id,
        since: f.updated_at
      },
      order_by: [desc: f.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  受信したフレンド申請を取得（pending）
  """
  def list_pending_requests(user_id) do
    from(f in Friendship,
      where: f.addressee_id == ^user_id and f.status == :pending,
      join: u in User,
      on: u.id == f.requester_id,
      select: %{
        id: f.id,
        requester_id: u.id,
        name: u.name,
        email: u.email,
        avatar: u.avatar,
        requested_at: f.inserted_at
      },
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  送信したフレンド申請を取得
  """
  def list_sent_requests(user_id) do
    from(f in Friendship,
      where: f.requester_id == ^user_id and f.status == :pending,
      join: u in User,
      on: u.id == f.addressee_id,
      select: %{
        id: f.id,
        addressee_id: u.id,
        name: u.name,
        email: u.email,
        avatar: u.avatar,
        sent_at: f.inserted_at
      },
      order_by: [desc: f.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  フレンド数を取得
  """
  def count_friends(user_id) do
    from(f in Friendship,
      where: f.status == :accepted,
      where: f.requester_id == ^user_id or f.addressee_id == ^user_id
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  pending申請数を取得
  """
  def count_pending_requests(user_id) do
    from(f in Friendship,
      where: f.addressee_id == ^user_id and f.status == :pending
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  二人がフレンドかどうか
  """
  def friends?(user_id, other_id) do
    case get_friendship(user_id, other_id) do
      %Friendship{status: :accepted} -> true
      _ -> false
    end
  end

  @doc """
  フレンド関係を取得（双方向）
  """
  def get_friendship(user1_id, user2_id) do
    from(f in Friendship,
      where:
        (f.requester_id == ^user1_id and f.addressee_id == ^user2_id) or
          (f.requester_id == ^user2_id and f.addressee_id == ^user1_id)
    )
    |> Repo.one()
  end

  # ============================================================
  # ゲーム履歴
  # ============================================================

  @doc """
  ゲーム履歴を記録（全プレイヤー間の関係を記録）
  """
  def record_game_history(room_id, player_ids) when is_list(player_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # 全ての組み合わせを作成
    entries =
      for user_id <- player_ids,
          played_with_id <- player_ids,
          user_id != played_with_id do
        %{
          user_id: user_id,
          played_with_id: played_with_id,
          room_id: room_id,
          played_at: now,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(GameHistory, entries, on_conflict: :nothing)
    :ok
  end

  @doc """
  最近遊んだ人を取得（フレンドでない人のみ）
  """
  def list_recent_players(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # フレンドIDのサブクエリ
    friend_ids_query =
      from(f in Friendship,
        where: f.status == :accepted,
        where: f.requester_id == ^user_id or f.addressee_id == ^user_id,
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            f.requester_id,
            ^user_id,
            f.addressee_id,
            f.requester_id
          )
      )

    from(gh in GameHistory,
      where: gh.user_id == ^user_id,
      where: gh.played_with_id not in subquery(friend_ids_query),
      join: u in User,
      on: u.id == gh.played_with_id,
      group_by: [u.id, u.name, u.email, u.avatar],
      select: %{
        id: u.id,
        name: u.name,
        email: u.email,
        avatar: u.avatar,
        play_count: count(gh.id),
        last_played: max(gh.played_at)
      },
      order_by: [desc: max(gh.played_at)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  特定のユーザーと何回遊んだか
  """
  def play_count_with(user_id, other_id) do
    from(gh in GameHistory,
      where: gh.user_id == ^user_id and gh.played_with_id == ^other_id
    )
    |> Repo.aggregate(:count, :id)
  end
end

