defmodule RogsComm.Rooms.Room do
  @moduledoc """
  Room entity representing a chat space that players can join.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rooms" do
    field :name, :string
    field :slug, :string
    field :topic, :string
    field :is_private, :boolean, default: false
    field :max_participants, :integer, default: 4
    # "game" = ゲーム用ロビー, "kamihakari" = 神議りの間
    field :category, :string, default: "game"

    # 削除関連フィールド
    field :host_id, :binary_id
    field :last_activity_at, :utc_datetime
    field :deletion_proposed_at, :utc_datetime
    field :deletion_votes, {:array, :binary_id}, default: []
    field :current_participants, :integer, default: 0

    # 招待コード（6桁英数字）
    field :invite_code, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :topic, :is_private, :max_participants, :category])
    |> ensure_slug()
    |> ensure_invite_code()
    |> validate_required([:name, :slug, :max_participants])
    |> validate_length(:name, min: 3, max: 120)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_inclusion(:category, ["game", "kamihakari"])
    |> validate_max_participants()
    |> unique_constraint(:slug)
    |> unique_constraint(:invite_code)
  end

  # 神議りの間は参加者数無制限（100人まで）、ゲームは2-4人
  defp validate_max_participants(changeset) do
    category = get_field(changeset, :category) || "game"

    case category do
      "kamihakari" ->
        validate_number(changeset, :max_participants,
          greater_than_or_equal_to: 1,
          less_than_or_equal_to: 100
        )

      _ ->
        validate_number(changeset, :max_participants,
          greater_than_or_equal_to: 2,
          less_than_or_equal_to: 4
        )
    end
  end

  defp ensure_slug(%Ecto.Changeset{} = changeset) do
    slug = get_field(changeset, :slug)

    case slug do
      value when is_binary(value) and value != "" ->
        changeset

      _ ->
        case get_field(changeset, :name) do
          nil ->
            changeset

          name ->
            put_change(changeset, :slug, slugify(name))
        end
    end
  end

  defp slugify(name) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    # 日本語などで空になった場合はランダムslugを生成
    case slug do
      "" -> generate_random_slug()
      s -> s
    end
  end

  defp generate_random_slug do
    # room-xxxx の形式でランダムslugを生成
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "room-#{random}"
  end

  # 招待コードがなければ生成
  defp ensure_invite_code(%Ecto.Changeset{} = changeset) do
    invite_code = get_field(changeset, :invite_code)

    case invite_code do
      value when is_binary(value) and value != "" ->
        changeset

      _ ->
        put_change(changeset, :invite_code, generate_invite_code())
    end
  end

  @doc """
  6桁の招待コードを生成（大文字英数字、紛らわしい文字を除外）
  """
  def generate_invite_code do
    # 紛らわしい文字を除外: 0, O, I, 1, L
    chars = ~c"ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    1..6
    |> Enum.map(fn _ -> Enum.random(chars) end)
    |> List.to_string()
  end
end
