defmodule Fittrack.Training.WorkoutSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Exercise
  alias Fittrack.Training.WorkoutSession

  schema "workout_sets" do
    field :weight, :decimal
    field :reps, :integer
    field :rpe, :decimal
    field :rest_seconds, :integer
    field :notes, :string

    belongs_to :workout_session, WorkoutSession
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_set, attrs) do
    workout_set
    |> cast(attrs, [:weight, :reps, :rpe, :rest_seconds, :notes, :exercise_id])
    |> validate_required([:weight, :reps, :exercise_id])
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> validate_number(:reps, greater_than: 0)
    |> validate_number(:rpe, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:rest_seconds, greater_than_or_equal_to: 0)
  end
end
