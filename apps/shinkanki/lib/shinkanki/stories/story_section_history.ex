defmodule Shinkanki.Stories.StorySectionHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_section_histories" do
    field :section_id, :string
    field :title, :string
    field :content, :string
    field :version, :integer
    field :updated_by, :binary_id

    belongs_to :story_section, Shinkanki.Stories.StorySection

    timestamps(updated_at: false)
  end

  def changeset(history, attrs) do
    history
    |> cast(attrs, [:story_section_id, :section_id, :title, :content, :version, :updated_by])
    |> validate_required([:story_section_id, :section_id, :title, :content, :version])
  end
end
