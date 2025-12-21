defmodule Shinkanki.Rulebook.RulebookSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rulebook_sections" do
    field :section_id, :string
    field :title, :string
    field :content, :string
    field :order_index, :integer, default: 0
    field :updated_by, :binary_id
    field :editor_name, :string
    field :version, :integer, default: 1

    has_many :histories, Shinkanki.Rulebook.RulebookSectionHistory

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:section_id, :title, :content, :order_index, :updated_by, :editor_name, :version])
    |> validate_required([:section_id, :title, :content])
    |> validate_length(:title, max: 200)
    |> validate_length(:content, max: 100_000)
    |> validate_length(:editor_name, max: 50)
    |> unique_constraint(:section_id)
  end
end
