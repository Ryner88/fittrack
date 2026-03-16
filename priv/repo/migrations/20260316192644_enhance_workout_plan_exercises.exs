defmodule Fittrack.Repo.Migrations.EnhanceWorkoutPlanExercises do
  use Ecto.Migration

  def change do
    # Rename existing columns
    rename table(:workout_plan_exercises), :order, to: :position
    rename table(:workout_plan_exercises), :sets, to: :target_sets

    # Add new columns
    alter table(:workout_plan_exercises) do
      add :target_reps_min, :integer
      add :target_reps_max, :integer
    end

    # Migrate existing reps data to the new format
    # For reps like "8-12", set min=8, max=12
    # For single values like "10", set min=10, max=10
    execute """
    UPDATE workout_plan_exercises
    SET target_reps_min = CASE
      WHEN reps ~ '^[0-9]+$' THEN CAST(reps AS INTEGER)
      WHEN reps ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(reps, '-', 1) AS INTEGER)
      ELSE 8
    END,
    target_reps_max = CASE
      WHEN reps ~ '^[0-9]+$' THEN CAST(reps AS INTEGER)
      WHEN reps ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(reps, '-', 2) AS INTEGER)
      ELSE 12
    END
    """

    # Remove the old reps column
    alter table(:workout_plan_exercises) do
      remove :reps
    end

    # Update indexes
    drop index(:workout_plan_exercises, [:workout_plan_id, :order])
    create unique_index(:workout_plan_exercises, [:workout_plan_id, :position])
  end
end
