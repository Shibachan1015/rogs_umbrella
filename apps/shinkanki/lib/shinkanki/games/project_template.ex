defmodule Shinkanki.Games.ProjectTemplate do
  @moduledoc """
  共創プロジェクトのテンプレート（マスターデータ）
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "project_templates" do
    field :name, :string
    field :description, :string
    field :required_participants, :integer, default: 4
    field :required_turns, :integer
    field :required_dao_pool, :integer
    field :effect_forest, :integer, default: 0
    field :effect_culture, :integer, default: 0
    field :effect_social, :integer, default: 0
    field :effect_akasha, :integer, default: 0
    field :permanent_effect, :string
    field :permanent_effect_value, :integer

    has_many :game_projects, Shinkanki.Games.GameProject

    timestamps()
  end

  @doc false
  def changeset(project_template, attrs) do
    project_template
    |> cast(attrs, [
      :name,
      :description,
      :required_participants,
      :required_turns,
      :required_dao_pool,
      :effect_forest,
      :effect_culture,
      :effect_social,
      :effect_akasha,
      :permanent_effect,
      :permanent_effect_value
    ])
    |> validate_required([:name])
    |> validate_number(:required_participants, greater_than: 0)
  end

  @doc """
  プロジェクトの完成条件をチェック
  """
  def completion_requirements(%__MODULE__{} = template) do
    %{
      participants: template.required_participants,
      turns: template.required_turns,
      dao_pool: template.required_dao_pool
    }
  end

  @doc """
  プロジェクト完成時の効果を取得
  """
  def get_effects(%__MODULE__{} = template) do
    %{
      forest: template.effect_forest,
      culture: template.effect_culture,
      social: template.effect_social,
      akasha: template.effect_akasha
    }
  end
end
