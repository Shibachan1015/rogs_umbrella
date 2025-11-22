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
    field :max_participants, :integer, default: 8

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :topic, :is_private, :max_participants])
    |> ensure_slug()
    |> validate_required([:name, :slug, :max_participants])
    |> validate_length(:name, min: 3, max: 120)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_number(:max_participants,
      greater_than_or_equal_to: 2,
      less_than_or_equal_to: 64
    )
    |> unique_constraint(:slug)
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
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> nil
      slug -> slug
    end
  end
end
