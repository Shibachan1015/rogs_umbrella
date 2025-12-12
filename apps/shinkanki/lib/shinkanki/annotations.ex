defmodule Shinkanki.Annotations do
  @moduledoc """
  The Annotations context.
  Handles page annotations/comments for rulebook and card pages.
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo
  alias Shinkanki.Annotations.PageAnnotation

  @doc """
  Returns the list of annotations for a specific page.
  """
  def list_annotations_for_page(page_path) do
    from(a in PageAnnotation,
      where: a.page_path == ^page_path,
      order_by: [asc: a.section_id, asc: a.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of annotations for a specific section on a page.
  """
  def list_annotations_for_section(page_path, section_id) do
    from(a in PageAnnotation,
      where: a.page_path == ^page_path and a.section_id == ^section_id,
      order_by: [asc: a.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of annotations by a specific user.
  """
  def list_user_annotations(user_id) do
    from(a in PageAnnotation,
      where: a.user_id == ^user_id,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single annotation.
  Returns nil if not found.
  """
  def get_annotation(id), do: Repo.get(PageAnnotation, id)

  @doc """
  Gets a single annotation.
  Raises if not found.
  """
  def get_annotation!(id), do: Repo.get!(PageAnnotation, id)

  @doc """
  Creates an annotation.
  """
  def create_annotation(attrs \\ %{}) do
    %PageAnnotation{}
    |> PageAnnotation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an annotation.
  Only the owner can update their annotation.
  """
  def update_annotation(%PageAnnotation{} = annotation, attrs, user_id) do
    if annotation.user_id == user_id do
      annotation
      |> PageAnnotation.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes an annotation.
  Only the owner can delete their annotation.
  """
  def delete_annotation(%PageAnnotation{} = annotation, user_id) do
    if annotation.user_id == user_id do
      Repo.delete(annotation)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking annotation changes.
  """
  def change_annotation(%PageAnnotation{} = annotation, attrs \\ %{}) do
    PageAnnotation.changeset(annotation, attrs)
  end

  @doc """
  Gets annotation counts grouped by section for a page.
  """
  def get_annotation_counts(page_path) do
    from(a in PageAnnotation,
      where: a.page_path == ^page_path,
      group_by: a.section_id,
      select: {a.section_id, count(a.id)}
    )
    |> Repo.all()
    |> Map.new()
  end
end
