defmodule Shinkanki.Stories.StorySection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_sections" do
    field :section_id, :string
    field :title, :string
    field :content, :string
    field :order_index, :integer, default: 0
    field :updated_by, :binary_id
    field :version, :integer, default: 1

    has_many :histories, Shinkanki.Stories.StorySectionHistory

    timestamps()
  end

  def changeset(story_section, attrs) do
    story_section
    |> cast(attrs, [:section_id, :title, :content, :order_index, :updated_by, :version])
    |> validate_required([:section_id, :title, :content])
    |> validate_length(:title, max: 200)
    |> validate_length(:content, max: 50_000)
    |> unique_constraint(:section_id)
  end
end
