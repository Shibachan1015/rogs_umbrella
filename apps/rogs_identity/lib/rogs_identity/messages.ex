defmodule RogsIdentity.Messages do
  @moduledoc """
  ダイレクトメッセージと招待機能のコンテキスト
  """

  import Ecto.Query, warn: false
  alias RogsIdentity.Repo
  alias RogsIdentity.Messages.{DirectMessage, RoomInvitation}
  alias RogsIdentity.Accounts.User
  alias RogsIdentity.Friends

  # ============================================================
  # ダイレクトメッセージ
  # ============================================================

  @doc """
  DMを送信（フレンドのみ）
  """
  def send_message(sender_id, receiver_id, content) do
    if Friends.friends?(sender_id, receiver_id) do
      %DirectMessage{}
      |> DirectMessage.changeset(%{
        sender_id: sender_id,
        receiver_id: receiver_id,
        content: content
      })
      |> Repo.insert()
      |> case do
        {:ok, message} ->
          # リアルタイム通知
          broadcast_new_message(message)
          {:ok, message}

        error ->
          error
      end
    else
      {:error, :not_friends}
    end
  end

  @doc """
  二人の間のメッセージ履歴を取得
  """
  def list_conversation(user1_id, user2_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    query =
      from(m in DirectMessage,
        where:
          (m.sender_id == ^user1_id and m.receiver_id == ^user2_id) or
            (m.sender_id == ^user2_id and m.receiver_id == ^user1_id),
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:sender]
      )

    query =
      if before_id do
        from(m in query, where: m.id < ^before_id)
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  @doc """
  会話リスト（最新のメッセージを持つフレンド一覧）
  """
  def list_conversations(user_id) do
    # 最新のメッセージを持つ相手を取得
    from(m in DirectMessage,
      where: m.sender_id == ^user_id or m.receiver_id == ^user_id,
      select: %{
        other_id:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            m.sender_id,
            ^user_id,
            m.receiver_id,
            m.sender_id
          ),
        last_message_at: max(m.inserted_at),
        last_content: fragment("(array_agg(? ORDER BY ? DESC))[1]", m.content, m.inserted_at)
      },
      group_by: [
        fragment(
          "CASE WHEN ? = ? THEN ? ELSE ? END",
          m.sender_id,
          ^user_id,
          m.receiver_id,
          m.sender_id
        )
      ],
      order_by: [desc: max(m.inserted_at)]
    )
    |> Repo.all()
    |> Enum.map(fn conv ->
      user = Repo.get(User, conv.other_id)

      %{
        user_id: conv.other_id,
        name: user && User.display_name(user),
        avatar: user && User.avatar(user),
        last_message_at: conv.last_message_at,
        last_content: conv.last_content,
        unread_count: count_unread(user_id, conv.other_id)
      }
    end)
  end

  @doc """
  メッセージを既読にする
  """
  def mark_as_read(user_id, sender_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(m in DirectMessage,
      where: m.receiver_id == ^user_id and m.sender_id == ^sender_id,
      where: is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  @doc """
  未読メッセージ数を取得（特定の相手から）
  """
  def count_unread(receiver_id, sender_id) do
    from(m in DirectMessage,
      where: m.receiver_id == ^receiver_id and m.sender_id == ^sender_id,
      where: is_nil(m.read_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  全未読メッセージ数を取得
  """
  def count_all_unread(user_id) do
    from(m in DirectMessage,
      where: m.receiver_id == ^user_id,
      where: is_nil(m.read_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  # ============================================================
  # ルーム招待
  # ============================================================

  @doc """
  フレンドを部屋に招待
  """
  def invite_to_room(sender_id, receiver_id, room) do
    if Friends.friends?(sender_id, receiver_id) do
      %RoomInvitation{}
      |> RoomInvitation.changeset(%{
        sender_id: sender_id,
        receiver_id: receiver_id,
        room_id: room.id,
        room_name: room.name,
        room_slug: room.slug
      })
      |> Repo.insert()
      |> case do
        {:ok, invitation} ->
          broadcast_invitation(invitation)
          {:ok, invitation}

        error ->
          error
      end
    else
      {:error, :not_friends}
    end
  end

  @doc """
  招待を承認
  """
  def accept_invitation(invitation_id, receiver_id) do
    case Repo.get(RoomInvitation, invitation_id) do
      nil ->
        {:error, :not_found}

      %RoomInvitation{receiver_id: ^receiver_id, status: :pending} = invitation ->
        if RoomInvitation.expired?(invitation) do
          invitation
          |> Ecto.Changeset.change(status: :expired)
          |> Repo.update()

          {:error, :expired}
        else
          invitation
          |> Ecto.Changeset.change(status: :accepted)
          |> Repo.update()
        end

      %RoomInvitation{receiver_id: ^receiver_id} ->
        {:error, :not_pending}

      _ ->
        {:error, :not_authorized}
    end
  end

  @doc """
  招待を辞退
  """
  def decline_invitation(invitation_id, receiver_id) do
    case Repo.get(RoomInvitation, invitation_id) do
      nil ->
        {:error, :not_found}

      %RoomInvitation{receiver_id: ^receiver_id, status: :pending} = invitation ->
        invitation
        |> Ecto.Changeset.change(status: :declined)
        |> Repo.update()

      %RoomInvitation{receiver_id: ^receiver_id} ->
        {:error, :not_pending}

      _ ->
        {:error, :not_authorized}
    end
  end

  @doc """
  pending招待一覧を取得
  """
  def list_pending_invitations(user_id) do
    now = DateTime.utc_now()

    from(i in RoomInvitation,
      where: i.receiver_id == ^user_id and i.status == :pending,
      where: i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:sender]
    )
    |> Repo.all()
  end

  @doc """
  pending招待数を取得
  """
  def count_pending_invitations(user_id) do
    now = DateTime.utc_now()

    from(i in RoomInvitation,
      where: i.receiver_id == ^user_id and i.status == :pending,
      where: i.expires_at > ^now
    )
    |> Repo.aggregate(:count, :id)
  end

  # ============================================================
  # PubSub ブロードキャスト
  # ============================================================

  defp broadcast_new_message(message) do
    topic = "dm:#{message.receiver_id}"
    Phoenix.PubSub.broadcast(RogsIdentity.PubSub, topic, {:new_message, message})
  end

  defp broadcast_invitation(invitation) do
    topic = "invitations:#{invitation.receiver_id}"
    Phoenix.PubSub.broadcast(RogsIdentity.PubSub, topic, {:new_invitation, invitation})
  end

  @doc """
  DMトピックを購読
  """
  def subscribe_dm(user_id) do
    Phoenix.PubSub.subscribe(RogsIdentity.PubSub, "dm:#{user_id}")
  end

  @doc """
  招待トピックを購読
  """
  def subscribe_invitations(user_id) do
    Phoenix.PubSub.subscribe(RogsIdentity.PubSub, "invitations:#{user_id}")
  end
end

