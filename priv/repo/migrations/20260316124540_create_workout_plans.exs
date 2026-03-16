defmodule Fittrack.Repo.Migrations.CreateWorkoutPlans do
  use Ecto.Migration

  def change do
    create table(:workout_plans) do
      add :name, :string, null: false
      add :description, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:workout_plans, [:user_id])
    create unique_index(:workout_plans, [:user_id, :name])

    create table(:workout_plan_exercises) do
      add :workout_plan_id, references(:workout_plans, on_delete: :delete_all), null: false
      add :exercise_id, references(:exercises, on_delete: :delete_all), null: false
      add :order, :integer, null: false
      add :sets, :integer, null: false
      # Allow ranges like "8-12"
      add :reps, :string, null: false
      add :rest_seconds, :integer, default: 60
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:workout_plan_exercises, [:workout_plan_id])
    create index(:workout_plan_exercises, [:exercise_id])
    create unique_index(:workout_plan_exercises, [:workout_plan_id, :order])
  end
end
