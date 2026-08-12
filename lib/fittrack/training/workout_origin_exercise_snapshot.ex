defmodule Fittrack.Training.WorkoutOriginExerciseSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.WorkoutOriginMuscleSnapshot
  alias Fittrack.Training.WorkoutOriginSnapshot

  schema "workout_origin_exercise_snapshots" do
    field :source_workout_plan_exercise_id, :integer
    field :source_exercise_id, :integer
    field :source_template_id, :integer

    field :position, :integer
    field :scheduled_day, :string
    field :target_sets, :integer
    field :target_reps_min, :integer
    field :target_reps_max, :integer
    field :rest_seconds, :integer
    field :target_kind, :string
    field :notes, :string

    field :exercise_name, :string
    field :exercise_slug, :string
    field :exercise_primary_muscle, :string
    field :exercise_secondary_muscles, {:array, :string}, default: []
    field :exercise_equipment, :string
    field :exercise_movement_pattern, :string
    field :exercise_category, :string
    field :exercise_training_style_tags, {:array, :string}, default: []

    field :template_name, :string
    field :template_canonical_slug, :string
    field :template_primary_muscle, :string
    field :template_secondary_muscles, {:array, :string}, default: []
    field :template_equipment, :string
    field :template_movement_pattern, :string
    field :template_exercise_category, :string
    field :template_training_style_tags, {:array, :string}, default: []

    belongs_to :origin_snapshot, WorkoutOriginSnapshot, foreign_key: :workout_origin_snapshot_id

    has_many :muscle_snapshots, WorkoutOriginMuscleSnapshot,
      on_replace: :delete,
      foreign_key: :workout_origin_exercise_snapshot_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :workout_origin_snapshot_id,
      :source_workout_plan_exercise_id,
      :source_exercise_id,
      :source_template_id,
      :position,
      :scheduled_day,
      :target_sets,
      :target_reps_min,
      :target_reps_max,
      :rest_seconds,
      :target_kind,
      :notes,
      :exercise_name,
      :exercise_slug,
      :exercise_primary_muscle,
      :exercise_secondary_muscles,
      :exercise_equipment,
      :exercise_movement_pattern,
      :exercise_category,
      :exercise_training_style_tags,
      :template_name,
      :template_canonical_slug,
      :template_primary_muscle,
      :template_secondary_muscles,
      :template_equipment,
      :template_movement_pattern,
      :template_exercise_category,
      :template_training_style_tags
    ])
    |> validate_required([
      :workout_origin_snapshot_id,
      :source_workout_plan_exercise_id,
      :source_exercise_id,
      :position,
      :exercise_name
    ])
    |> validate_number(:position, greater_than: 0)
    |> foreign_key_constraint(:workout_origin_snapshot_id)
    |> unique_constraint(:position, name: :workout_origin_exercise_snapshots_order_idx)
  end
end
