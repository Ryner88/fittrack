defmodule Fittrack.Repo.Migrations.AddMetadataToWorkoutPlans do
  use Ecto.Migration

  def change do
    alter table(:workout_plans) do
      add :primary_style, :string
      add :secondary_style_tags, {:array, :string}, default: []
      add :goal, :string
      add :difficulty, :string
      add :estimated_duration_minutes, :integer
    end

    create index(:workout_plans, [:primary_style])
    create index(:workout_plans, [:difficulty])

    execute """
            CREATE INDEX workout_plans_secondary_style_tags_gin_idx
            ON workout_plans
            USING GIN (secondary_style_tags)
            """,
            """
            DROP INDEX workout_plans_secondary_style_tags_gin_idx
            """
  end
end
