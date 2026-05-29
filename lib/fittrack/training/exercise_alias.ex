defmodule Fittrack.Training.ExerciseAlias do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.Slug

  schema "exercise_aliases" do
    field :name, :string
    field :normalized_name, :string
    field :slug, :string
    field :kind, :string, default: "alias"
    field :source, :string
    field :weight, :integer, default: 1

    belongs_to :exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(alias_record, attrs) do
    alias_record
    |> cast(attrs, [:exercise_template_id, :name, :kind, :source, :weight])
    |> validate_required([:exercise_template_id, :name, :kind])
    |> validate_inclusion(:kind, ["canonical", "alias", "abbreviation", "imported"])
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> update_change(:name, &String.trim/1)
    |> update_change(:source, &trim_optional/1)
    |> put_normalized_fields()
    |> unique_constraint([:exercise_template_id, :normalized_name])
    |> unique_constraint(:slug)
  end

  defp put_normalized_fields(changeset) do
    name = get_field(changeset, :name)

    changeset
    |> put_change(:normalized_name, Normalizer.normalize_text(name))
    |> put_change(:slug, Slug.slugify(name))
  end

  defp trim_optional(value) when is_binary(value), do: String.trim(value)
  defp trim_optional(value), do: value
end
