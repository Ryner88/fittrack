defmodule Fittrack.Training.WorkoutPlanExercise do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.WorkoutPlan
  alias Fittrack.Training.Exercise

  schema "workout_plan_exercises" do
    field :position, :integer
    field :target_sets, :integer
    field :target_reps_min, :integer
    field :target_reps_max, :integer
    field :rest_seconds, :integer
    field :notes, :string
    field :scheduled_day, :string

    belongs_to :workout_plan, WorkoutPlan
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_plan_exercise, attrs) do
    workout_plan_exercise
    |> cast(attrs, [
      :position,
      :target_sets,
      :target_reps_min,
      :target_reps_max,
      :rest_seconds,
      :scheduled_day,
      :notes,
      :workout_plan_id,
      :exercise_id
    ])
    |> validate_required([:position, :exercise_id])
    |> validate_number(:position, greater_than: 0)
    |> validate_number(:target_sets, greater_than: 0)
    |> validate_number(:target_reps_min, greater_than: 0)
    |> validate_number(:target_reps_max, greater_than: 0)
    |> validate_reps_range()
    |> validate_number(:rest_seconds, greater_than_or_equal_to: 0)
    |> validate_inclusion(:scheduled_day, [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      nil
    ])
    |> update_change(:notes, &String.trim/1)
    |> foreign_key_constraint(:workout_plan_id)
    |> foreign_key_constraint(:exercise_id)
  end

  defp validate_reps_range(changeset) do
    min = get_field(changeset, :target_reps_min)
    max = get_field(changeset, :target_reps_max)

    cond do
      is_nil(min) or is_nil(max) ->
        changeset

      min <= max ->
        changeset

      true ->
        add_error(changeset, :target_reps_max, "must be greater than or equal to min reps")
    end
  end
end
