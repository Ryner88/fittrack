defmodule Fittrack.Training.WorkoutOriginSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Workout
  alias Fittrack.Training.WorkoutOriginExerciseSnapshot

  @schema_version 1

  schema "workout_origin_snapshots" do
    field :source_workout_plan_id, :integer
    field :schema_version, :integer, default: @schema_version
    field :captured_at, :utc_datetime

    field :plan_name, :string
    field :plan_description, :string
    field :plan_goal, :string
    field :plan_primary_style, :string
    field :plan_secondary_style_tags, {:array, :string}, default: []
    field :plan_primary_goal, :string
    field :plan_secondary_goal, :string
    field :plan_tertiary_goal, :string
    field :plan_additional_goal, :string
    field :plan_training_styles, {:array, :string}, default: []
    field :plan_training_split, {:array, :string}, default: []
    field :plan_difficulty, :string
    field :plan_estimated_duration_minutes, :integer

    belongs_to :workout, Workout, foreign_key: :workout_session_id

    has_many :exercise_snapshots, WorkoutOriginExerciseSnapshot,
      on_replace: :delete,
      foreign_key: :workout_origin_snapshot_id

    timestamps(type: :utc_datetime)
  end

  def schema_version, do: @schema_version

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :workout_session_id,
      :source_workout_plan_id,
      :schema_version,
      :captured_at,
      :plan_name,
      :plan_description,
      :plan_goal,
      :plan_primary_style,
      :plan_secondary_style_tags,
      :plan_primary_goal,
      :plan_secondary_goal,
      :plan_tertiary_goal,
      :plan_additional_goal,
      :plan_training_styles,
      :plan_training_split,
      :plan_difficulty,
      :plan_estimated_duration_minutes
    ])
    |> validate_required([
      :workout_session_id,
      :source_workout_plan_id,
      :schema_version,
      :captured_at,
      :plan_name
    ])
    |> validate_inclusion(:schema_version, [@schema_version])
    |> foreign_key_constraint(:workout_session_id)
    |> unique_constraint(:workout_session_id)
    |> check_constraint(:schema_version, name: :workout_origin_snapshots_schema_version_check)
  end
end
