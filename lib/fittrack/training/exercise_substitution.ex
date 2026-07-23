defmodule Fittrack.Training.ExerciseSubstitution do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.RelationshipNormalizer

  schema "exercise_substitutions" do
    field :reason, :string
    field :priority, :integer, default: 0
    field :notes, :string
    field :similarity_score, :integer
    field :equipment_requirements, {:array, :string}, default: []
    field :difficulty_delta, :integer
    field :reason_quality, :integer

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
      :similarity_score,
      :equipment_requirements,
      :difficulty_delta,
      :reason_quality,
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
    |> validate_number(:similarity_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_number(:difficulty_delta,
      greater_than_or_equal_to: -5,
      less_than_or_equal_to: 5
    )
    |> validate_number(:reason_quality,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> update_change(:equipment_requirements, &RelationshipNormalizer.normalize_list/1)
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
