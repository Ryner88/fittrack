defmodule Fittrack.Repo.Migrations.AddAiGeneratorPreferencesToWorkoutPlans do
  use Ecto.Migration

  def change do
    alter table(:workout_plans) do
      add :primary_goal, :string
      add :secondary_goal, :string
      add :tertiary_goal, :string
      add :additional_goal, :string
      add :training_styles, {:array, :string}, default: [], null: false
      add :training_split, {:array, :string}, default: [], null: false
    end

    execute(
      """
      UPDATE workout_plans
      SET primary_goal = goal
      WHERE primary_goal IS NULL AND goal IS NOT NULL
      """,
      """
      UPDATE workout_plans
      SET primary_goal = NULL
      WHERE primary_goal = goal
      """
    )

    create index(:workout_plans, [:primary_goal])

    execute(
      """
      CREATE INDEX workout_plans_training_styles_gin_idx
      ON workout_plans
      USING GIN (training_styles)
      """,
      "DROP INDEX workout_plans_training_styles_gin_idx"
    )

    execute(
      """
      CREATE INDEX workout_plans_training_split_gin_idx
      ON workout_plans
      USING GIN (training_split)
      """,
      "DROP INDEX workout_plans_training_split_gin_idx"
    )
  end
end
