defmodule Fittrack.Repo.Migrations.AddWorkoutLifecycleState do
  use Ecto.Migration

  def up do
    alter table(:workout_sessions) do
      add :lifecycle_state, :string
      add :completed_at, :utc_datetime
      add :discarded_at, :utc_datetime
    end

    execute """
    UPDATE workout_sessions AS workout
    SET
      lifecycle_state = 'completed',
      completed_at = COALESCE(
        (
          SELECT MAX(workout_sets.inserted_at)
          FROM workout_sets
          WHERE workout_sets.workout_session_id = workout.id
        ),
        workout.updated_at,
        workout.started_at
      )
    WHERE EXISTS (
      SELECT 1
      FROM workout_sets
      WHERE workout_sets.workout_session_id = workout.id
    )
    """

    execute """
    WITH empty_workouts AS (
      SELECT
        workout.id,
        ROW_NUMBER() OVER (
          PARTITION BY workout.user_id
          ORDER BY workout.started_at DESC, workout.id DESC
        ) AS position
      FROM workout_sessions AS workout
      WHERE NOT EXISTS (
        SELECT 1
        FROM workout_sets
        WHERE workout_sets.workout_session_id = workout.id
      )
    )
    UPDATE workout_sessions AS workout
    SET
      lifecycle_state = CASE
        WHEN empty_workouts.position = 1 THEN 'draft'
        ELSE 'discarded'
      END,
      discarded_at = CASE
        WHEN empty_workouts.position = 1 THEN NULL
        ELSE COALESCE(workout.updated_at, workout.started_at)
      END
    FROM empty_workouts
    WHERE workout.id = empty_workouts.id
    """

    alter table(:workout_sessions) do
      modify :lifecycle_state, :string, null: false
    end

    create constraint(:workout_sessions, :workout_sessions_lifecycle_state_check,
             check: "lifecycle_state IN ('draft', 'active', 'completed', 'discarded')"
           )

    create unique_index(:workout_sessions, [:user_id],
             name: :workout_sessions_one_open_per_user_idx,
             where: "lifecycle_state IN ('draft', 'active')"
           )
  end

  def down do
    drop_if_exists index(:workout_sessions, [:user_id],
                     name: :workout_sessions_one_open_per_user_idx
                   )

    drop constraint(:workout_sessions, :workout_sessions_lifecycle_state_check)

    alter table(:workout_sessions) do
      remove :discarded_at
      remove :completed_at
      remove :lifecycle_state
    end
  end
end
