defmodule Fittrack.Repo.Migrations.AddTargetKindToWorkoutPlanExercises do
  use Ecto.Migration

  def change do
    alter table(:workout_plan_exercises) do
      add :target_kind, :string, null: false, default: "normal"
    end
  end
end
