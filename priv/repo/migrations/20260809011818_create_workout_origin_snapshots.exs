defmodule Fittrack.Repo.Migrations.CreateWorkoutOriginSnapshots do
  use Ecto.Migration

  def change do
    create table(:workout_origin_snapshots) do
      add :workout_session_id, references(:workout_sessions, on_delete: :delete_all), null: false
      add :source_workout_plan_id, :bigint, null: false
      add :schema_version, :integer, null: false, default: 1
      add :captured_at, :utc_datetime, null: false

      add :plan_name, :string, null: false
      add :plan_description, :text
      add :plan_goal, :string
      add :plan_primary_style, :string
      add :plan_secondary_style_tags, {:array, :string}, null: false, default: []
      add :plan_primary_goal, :string
      add :plan_secondary_goal, :string
      add :plan_tertiary_goal, :string
      add :plan_additional_goal, :string
      add :plan_training_styles, {:array, :string}, null: false, default: []
      add :plan_training_split, {:array, :string}, null: false, default: []
      add :plan_difficulty, :string
      add :plan_estimated_duration_minutes, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workout_origin_snapshots, [:workout_session_id])

    create constraint(:workout_origin_snapshots, :workout_origin_snapshots_schema_version_check,
             check: "schema_version = 1"
           )

    create table(:workout_origin_exercise_snapshots) do
      add :workout_origin_snapshot_id,
          references(:workout_origin_snapshots, on_delete: :delete_all),
          null: false

      add :source_workout_plan_exercise_id, :bigint, null: false
      add :source_exercise_id, :bigint, null: false
      add :source_template_id, :bigint

      add :position, :integer, null: false
      add :scheduled_day, :string
      add :target_sets, :integer
      add :target_reps_min, :integer
      add :target_reps_max, :integer
      add :rest_seconds, :integer
      add :target_kind, :string
      add :notes, :text

      add :exercise_name, :string, null: false
      add :exercise_slug, :string
      add :exercise_primary_muscle, :string
      add :exercise_secondary_muscles, {:array, :string}, null: false, default: []
      add :exercise_equipment, :string
      add :exercise_movement_pattern, :string
      add :exercise_category, :string
      add :exercise_training_style_tags, {:array, :string}, null: false, default: []

      add :template_name, :string
      add :template_canonical_slug, :string
      add :template_primary_muscle, :string
      add :template_secondary_muscles, {:array, :string}, null: false, default: []
      add :template_equipment, :string
      add :template_movement_pattern, :string
      add :template_exercise_category, :string
      add :template_training_style_tags, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :workout_origin_exercise_snapshots,
             [:workout_origin_snapshot_id, :position, :source_workout_plan_exercise_id],
             name: :workout_origin_exercise_snapshots_order_idx
           )

    create table(:workout_origin_muscle_snapshots) do
      add :workout_origin_exercise_snapshot_id,
          references(:workout_origin_exercise_snapshots, on_delete: :delete_all),
          null: false

      add :source_exercise_muscle_id, :bigint, null: false
      add :muscle_name, :string, null: false
      add :muscle_normalized_name, :string
      add :muscle_region, :string
      add :role, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create constraint(:workout_origin_muscle_snapshots,
             :workout_origin_muscle_snapshots_role_check,
             check: "role IN ('primary', 'secondary')"
           )

    create unique_index(
             :workout_origin_muscle_snapshots,
             [
               :workout_origin_exercise_snapshot_id,
               :role,
               :position,
               :source_exercise_muscle_id
             ],
             name: :workout_origin_muscle_snapshots_order_idx
           )
  end
end
