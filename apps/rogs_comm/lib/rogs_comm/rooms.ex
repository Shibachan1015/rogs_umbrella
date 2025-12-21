defmodule RogsComm.Rooms do
  @moduledoc """
  Provides the data access API for chat rooms, including creation,
  retrieval, and lifecycle helpers.
  """

  import Ecto.Query, warn: false

  alias RogsComm.Repo
  alias RogsComm.Rooms.Room

  @doc """
  ルーム一覧を取得します。

  ## Options
    - `:category` - カテゴリでフィルタ ("game" or "kamihakari")
    - `:include_private` - プライベートルームを含める (デフォルト: true)
    - `:search` - ルーム名またはトピックで検索
    - `:has_space` - 空きがあるルームのみ (デフォルト: false)
    - `:limit` - 取得件数の上限
  """
  def list_rooms(opts \\ []) do
    category = Keyword.get(opts, :category, nil)
    include_private? = Keyword.get(opts, :include_private, true)
    search = Keyword.get(opts, :search, nil)
    has_space? = Keyword.get(opts, :has_space, false)
    limit = Keyword.get(opts, :limit, nil)

    Room
    |> maybe_filter_category(category)
    |> maybe_filter_private(include_private?)
    |> maybe_filter_search(search)
    |> maybe_filter_has_space(has_space?)
    |> order_by([r], desc: r.inserted_at)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category) do
    from r in query, where: r.category == ^category
  end

  defp maybe_filter_private(query, true), do: query

  defp maybe_filter_private(query, false) do
    from r in query, where: r.is_private == false
  end

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) do
    search_term = "%#{search}%"

    from r in query,
      where: ilike(r.name, ^search_term) or ilike(r.topic, ^search_term)
  end

  defp maybe_filter_has_space(query, false), do: query

  defp maybe_filter_has_space(query, true) do
    from r in query, where: r.current_participants < r.max_participants
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  @doc """
  Gets a single room by ID.
  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Fetches a room by ID, returning `nil` when not found.
  """
  def fetch_room(id), do: Repo.get(Room, id)

  @doc """
  Gets a room by slug, raising when not found.
  """
  def get_room_by_slug!(slug) when is_binary(slug) do
    Repo.get_by!(Room, slug: slug)
  end

  @doc """
  Fetches a room by slug, returning `nil` when not found.
  """
  def fetch_room_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Room, slug: slug)
  end

  @doc """
  Creates a room.
  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.
  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  # ============================================================
  # Room Deletion & Activity Management
  # ============================================================

  @doc """
  ルーム作成時にホストを設定し、アクティビティを更新
  """
  def create_room_with_host(attrs, host_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.put("host_id", host_id)
      |> Map.put("last_activity_at", now)

    %Room{}
    |> Room.changeset(attrs)
    |> Ecto.Changeset.put_change(:host_id, host_id)
    |> Ecto.Changeset.put_change(:last_activity_at, now)
    |> Repo.insert()
  end

  @doc """
  ルームのアクティビティを更新
  """
  def touch_activity(%Room{} = room) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    room
    |> Ecto.Changeset.change(last_activity_at: now)
    |> Repo.update()
  end

  def touch_activity(room_id) when is_binary(room_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(r in Room, where: r.id == ^room_id)
    |> Repo.update_all(set: [last_activity_at: now])
  end

  @doc """
  参加者数を更新
  """
  def update_participant_count(room_id, count) when is_binary(room_id) do
    from(r in Room, where: r.id == ^room_id)
    |> Repo.update_all(set: [current_participants: count])
  end

  @doc """
  ホストが削除提案を開始
  """
  def propose_deletion(%Room{} = room, proposer_id) do
    if room.host_id == proposer_id do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      room
      |> Ecto.Changeset.change(
        deletion_proposed_at: now,
        deletion_votes: [proposer_id]
      )
      |> Repo.update()
    else
      {:error, :not_host}
    end
  end

  @doc """
  削除に投票（1日1回制限）
  """
  def vote_for_deletion(%Room{} = room, voter_id) do
    cond do
      # 削除提案がない
      is_nil(room.deletion_proposed_at) ->
        {:error, :no_proposal}

      # すでに投票済み
      voter_id in (room.deletion_votes || []) ->
        {:error, :already_voted}

      # 投票期限切れ（24時間）
      DateTime.diff(DateTime.utc_now(), room.deletion_proposed_at, :hour) >= 24 ->
        # 投票をリセット
        room
        |> Ecto.Changeset.change(deletion_proposed_at: nil, deletion_votes: [])
        |> Repo.update()

        {:error, :proposal_expired}

      true ->
        new_votes = (room.deletion_votes || []) ++ [voter_id]

        room
        |> Ecto.Changeset.change(deletion_votes: new_votes)
        |> Repo.update()
    end
  end

  @doc """
  過半数の投票があるか確認し、あれば削除
  """
  def check_and_delete_if_voted(%Room{} = room) do
    vote_count = length(room.deletion_votes || [])
    required = div(room.current_participants, 2) + 1

    if vote_count >= required and room.current_participants > 0 do
      delete_room(room)
      {:ok, :deleted}
    else
      {:ok, :waiting, vote_count, required}
    end
  end

  @doc """
  削除提案をキャンセル
  """
  def cancel_deletion_proposal(%Room{} = room) do
    room
    |> Ecto.Changeset.change(deletion_proposed_at: nil, deletion_votes: [])
    |> Repo.update()
  end

  @doc """
  空きルーム（0人で10分以上）を削除
  ※神議りの間（kamihakari）は削除しない
  """
  def cleanup_empty_rooms do
    ten_minutes_ago =
      DateTime.utc_now()
      |> DateTime.add(-10, :minute)
      |> DateTime.truncate(:second)

    from(r in Room,
      where: r.current_participants == 0,
      where: r.last_activity_at < ^ten_minutes_ago,
      where: r.category != "kamihakari"
    )
    |> Repo.delete_all()
  end

  @doc """
  無活動ルーム（12時間以上）を削除
  ※神議りの間（kamihakari）は削除しない
  """
  def cleanup_inactive_rooms do
    twelve_hours_ago =
      DateTime.utc_now()
      |> DateTime.add(-12, :hour)
      |> DateTime.truncate(:second)

    from(r in Room,
      where: r.last_activity_at < ^twelve_hours_ago,
      where: r.category != "kamihakari"
    )
    |> Repo.delete_all()
  end

  @doc """
  次のホストを設定（現在のホストが抜けた場合）
  """
  def transfer_host(%Room{} = room, new_host_id) do
    room
    |> Ecto.Changeset.change(host_id: new_host_id)
    |> Repo.update()
  end

  @doc """
  管理者がルームを即座に削除
  """
  def admin_delete_room(%Room{} = room, admin_user) do
    if RogsIdentity.Accounts.admin?(admin_user) do
      delete_room(room)
    else
      {:error, :not_admin}
    end
  end

  @doc """
  管理者がルームを強制削除（room_id指定）
  """
  def admin_delete_room_by_id(room_id, admin_user) do
    if RogsIdentity.Accounts.admin?(admin_user) do
      case fetch_room(room_id) do
        nil -> {:error, :not_found}
        room -> delete_room(room)
      end
    else
      {:error, :not_admin}
    end
  end

  # ============================================================
  # Quick Match & Invite Code
  # ============================================================

  @doc """
  招待コードでルームを取得
  """
  def get_room_by_invite_code(code) when is_binary(code) do
    code = String.upcase(String.trim(code))
    Repo.get_by(Room, invite_code: code)
  end

  @doc """
  クイックマッチ用に空きのあるゲームルームを1つ取得
  - 公開ルームのみ
  - ゲームカテゴリのみ
  - 空きがあるルーム
  - 参加者が多い順（にぎやかなルームを優先）
  """
  def find_available_room do
    Room
    |> where([r], r.category == "game")
    |> where([r], r.is_private == false)
    |> where([r], r.current_participants > 0)
    |> where([r], r.current_participants < r.max_participants)
    |> order_by([r], desc: r.current_participants, asc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  クイックマッチを実行
  - 空きルームがあれば返す
  - なければ新規ルームを作成
  """
  def quick_match(host_id) do
    case find_available_room() do
      nil ->
        # 空きルームがないので新規作成
        room_name = "クイックマッチ ##{:rand.uniform(9999)}"

        create_room_with_host(
          %{"name" => room_name, "category" => "game", "max_participants" => 4},
          host_id
        )

      room ->
        {:ok, room}
    end
  end
end
