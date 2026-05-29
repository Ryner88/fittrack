defmodule Fittrack.Training.ExerciseVariation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_variations" do
    field :relationship, :string
    field :notes, :string

    belongs_to :base_exercise_template, ExerciseTemplate
    belongs_to :variation_exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(variation, attrs) do
    variation
    |> cast(attrs, [
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship,
      :notes
    ])
    |> validate_required([
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship
    ])
    |> validate_inclusion(:relationship, [
      "angle",
      "implement",
      "stance",
      "progression",
      "regression"
    ])
    |> validate_not_self_referential()
    |> unique_constraint([
      :base_exercise_template_id,
      :variation_exercise_template_id,
      :relationship
    ])
    |> check_constraint(:base_exercise_template_id,
      name: :exercise_variations_no_self_reference
    )
  end

  defp validate_not_self_referential(changeset) do
    base_id = get_field(changeset, :base_exercise_template_id)
    variation_id = get_field(changeset, :variation_exercise_template_id)

    if base_id && variation_id && base_id == variation_id do
      add_error(
        changeset,
        :variation_exercise_template_id,
        "must be different from base exercise"
      )
    else
      changeset
    end
  end
end
