# 神議りの間 - 初期チャンネル作成
#
# 実行方法:
#   mix run apps/rogs_comm/priv/repo/seeds/kamihakari_channels.exs
#

alias RogsComm.Rooms
alias RogsComm.Rooms.Room

channels = [
  %{
    name: "#祈願",
    slug: "kigan",
    topic: "機能要望・アイデアを共有する場所",
    category: "kamihakari",
    max_participants: 100,
    is_private: false
  },
  %{
    name: "#浄化",
    slug: "jouka",
    topic: "バグ報告・不具合を共有する場所",
    category: "kamihakari",
    max_participants: 100,
    is_private: false
  },
  %{
    name: "#談話",
    slug: "danwa",
    topic: "雑談・交流の場所",
    category: "kamihakari",
    max_participants: 100,
    is_private: false
  },
  %{
    name: "#神託",
    slug: "shintaku",
    topic: "開発者からのお知らせ",
    category: "kamihakari",
    max_participants: 100,
    is_private: false
  }
]

IO.puts("神議りの間チャンネルを作成中...")

for channel <- channels do
  case Rooms.fetch_room_by_slug(channel.slug) do
    nil ->
      case Rooms.create_room(channel) do
        {:ok, room} ->
          IO.puts("✓ #{room.name} (#{room.slug}) を作成しました")

        {:error, changeset} ->
          IO.puts("✗ #{channel.name} の作成に失敗: #{inspect(changeset.errors)}")
      end

    existing ->
      IO.puts("- #{existing.name} (#{existing.slug}) は既に存在します")
  end
end

IO.puts("\n完了!")
