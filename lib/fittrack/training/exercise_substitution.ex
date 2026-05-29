defmodule Fittrack.Training.ExerciseSubstitution do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_substitutions" do
    field :reason, :string
    field :priority, :integer, default: 0
    field :notes, :string

    belongs_to :exercise_template, ExerciseTemplate
    belongs_to :substitute_exercise_template, ExerciseTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(substitution, attrs) do
    substitution
    |> cast(attrs, [
      :exercise_template_id,
      :substitute_exercise_template_id,
      :reason,
      :priority,
      :notes
    ])
    |> validate_required([:exercise_template_id, :substitute_exercise_template_id])
    |> validate_inclusion(:reason, [
      "equipment",
      "difficulty",
      "joint_friendly",
      "home_training",
      "same_pattern"
    ])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_not_self_referential()
    |> unique_constraint([:exercise_template_id, :substitute_exercise_template_id])
    |> check_constraint(:exercise_template_id, name: :exercise_substitutions_no_self_reference)
  end

  defp validate_not_self_referential(changeset) do
    exercise_id = get_field(changeset, :exercise_template_id)
    substitute_id = get_field(changeset, :substitute_exercise_template_id)

    if exercise_id && substitute_id && exercise_id == substitute_id do
      add_error(changeset, :substitute_exercise_template_id, "must be different from exercise")
    else
      changeset
    end
  end
end
