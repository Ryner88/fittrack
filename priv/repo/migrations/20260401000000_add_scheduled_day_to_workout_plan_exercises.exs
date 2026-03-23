defmodule Fittrack.Repo.Migrations.AddScheduledDayToWorkoutPlanExercises do
  use Ecto.Migration

  def change do
    alter table(:workout_plan_exercises) do
      add :scheduled_day, :string
    end

    create index(:workout_plan_exercises, [:scheduled_day])
  end
end
