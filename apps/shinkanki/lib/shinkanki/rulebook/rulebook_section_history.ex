defmodule Shinkanki.Rulebook.RulebookSectionHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rulebook_section_histories" do
    field :section_id, :string
    field :title, :string
    field :content, :string
    field :version, :integer
    field :updated_by, :binary_id
    field :editor_name, :string

    belongs_to :rulebook_section, Shinkanki.Rulebook.RulebookSection

    timestamps(updated_at: false)
  end

  def changeset(history, attrs) do
    history
    |> cast(attrs, [:rulebook_section_id, :section_id, :title, :content, :version, :updated_by, :editor_name])
    |> validate_required([:rulebook_section_id, :section_id, :title, :content, :version])
  end
end
