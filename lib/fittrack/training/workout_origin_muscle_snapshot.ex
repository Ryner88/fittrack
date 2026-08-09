defmodule Fittrack.Training.WorkoutOriginMuscleSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.WorkoutOriginExerciseSnapshot

  schema "workout_origin_muscle_snapshots" do
    field :source_exercise_muscle_id, :integer
    field :muscle_name, :string
    field :muscle_normalized_name, :string
    field :muscle_region, :string
    field :role, :string
    field :position, :integer, default: 0

    belongs_to :exercise_snapshot, WorkoutOriginExerciseSnapshot,
      foreign_key: :workout_origin_exercise_snapshot_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :workout_origin_exercise_snapshot_id,
      :source_exercise_muscle_id,
      :muscle_name,
      :muscle_normalized_name,
      :muscle_region,
      :role,
      :position
    ])
    |> validate_required([
      :workout_origin_exercise_snapshot_id,
      :source_exercise_muscle_id,
      :muscle_name,
      :role,
      :position
    ])
    |> validate_inclusion(:role, ["primary", "secondary"])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:workout_origin_exercise_snapshot_id)
    |> check_constraint(:role, name: :workout_origin_muscle_snapshots_role_check)
    |> unique_constraint(:position, name: :workout_origin_muscle_snapshots_order_idx)
  end
end
