defmodule Fittrack.Repo.Migrations.CreateWorkoutSessionsAndSets do
  use Ecto.Migration

  def change do
    create table(:workout_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime, null: false
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:workout_sessions, [:user_id])
    create index(:workout_sessions, [:started_at])

    create table(:workout_sets) do
      add :workout_session_id, references(:workout_sessions, on_delete: :delete_all), null: false
      add :exercise_id, references(:exercises, on_delete: :delete_all), null: false
      add :weight, :decimal, null: false
      add :reps, :integer, null: false
      add :rpe, :decimal
      add :rest_seconds, :integer
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:workout_sets, [:workout_session_id])
    create index(:workout_sets, [:exercise_id])
  end
end
