defmodule Fittrack.Repo.Migrations.CreateWorkoutMuscleSummaries do
  use Ecto.Migration

  def change do
    create table(:workout_muscle_summaries) do
      add :workout_session_id, references(:workout_sessions, on_delete: :delete_all), null: false
      add :muscle_token, :string, null: false
      add :muscle_name, :string, null: false
      add :muscle_normalized_name, :string
      add :role, :string, null: false
      add :sets, :integer, null: false, default: 0
      add :reps, :integer, null: false, default: 0
      add :volume, :decimal, precision: 12, scale: 2, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create constraint(:workout_muscle_summaries,
             :workout_muscle_summaries_role_check,
             check: "role IN ('primary', 'secondary')"
           )

    create constraint(:workout_muscle_summaries,
             :workout_muscle_summaries_sets_check,
             check: "sets >= 0"
           )

    create constraint(:workout_muscle_summaries,
             :workout_muscle_summaries_reps_check,
             check: "reps >= 0"
           )

    create constraint(:workout_muscle_summaries,
             :workout_muscle_summaries_volume_check,
             check: "volume >= 0"
           )

    create unique_index(:workout_muscle_summaries, [:workout_session_id, :muscle_token, :role],
             name: :workout_muscle_summaries_workout_token_role_idx
           )

    create index(:workout_muscle_summaries, [:muscle_token])
    create index(:workout_muscle_summaries, [:role])
  end
end
