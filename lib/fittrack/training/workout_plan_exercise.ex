defmodule Fittrack.Training.WorkoutPlanExercise do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.WorkoutPlan
  alias Fittrack.Training.Exercise

  schema "workout_plan_exercises" do
    field :order, :integer
    field :sets, :integer
    field :reps, :string
    field :rest_seconds, :integer
    field :notes, :string

    belongs_to :workout_plan, WorkoutPlan
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_plan_exercise, attrs) do
    workout_plan_exercise
    |> cast(attrs, [:order, :sets, :reps, :rest_seconds, :notes, :exercise_id])
    |> validate_required([:order, :sets, :reps, :exercise_id])
    |> validate_number(:sets, greater_than: 0)
    |> validate_number(:rest_seconds, greater_than_or_equal_to: 0)
    |> update_change(:reps, &String.trim/1)
    |> update_change(:notes, &String.trim/1)
    |> foreign_key_constraint(:workout_plan_id)
    |> foreign_key_constraint(:exercise_id)
  end
end
