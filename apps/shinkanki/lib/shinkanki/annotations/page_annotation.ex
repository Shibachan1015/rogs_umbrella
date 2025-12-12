defmodule Shinkanki.Annotations.PageAnnotation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "page_annotations" do
    field :user_id, :binary_id
    field :page_path, :string
    field :section_id, :string
    field :content, :string

    timestamps()
  end

  @doc """
  Changeset for creating or updating an annotation.
  """
  def changeset(annotation, attrs) do
    annotation
    |> cast(attrs, [:user_id, :page_path, :section_id, :content])
    |> validate_required([:user_id, :page_path, :section_id, :content])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_length(:section_id, max: 100)
    |> validate_length(:page_path, max: 255)
  end
end
