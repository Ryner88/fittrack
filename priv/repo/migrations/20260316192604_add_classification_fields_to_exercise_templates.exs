defmodule Fittrack.Repo.Migrations.AddClassificationFieldsToExerciseTemplates do
  use Ecto.Migration

  def change do
    alter table(:exercise_templates) do
      add :movement_pattern, :string
      add :exercise_category, :string
      add :training_style_tags, {:array, :string}, default: []
      add :secondary_muscles, {:array, :string}, default: []
    end

    create index(:exercise_templates, [:movement_pattern])
    create index(:exercise_templates, [:exercise_category])

    execute """
            CREATE INDEX exercise_templates_training_style_tags_gin_idx
            ON exercise_templates
            USING GIN (training_style_tags)
            """,
            """
            DROP INDEX exercise_templates_training_style_tags_gin_idx
            """

    execute """
            CREATE INDEX exercise_templates_secondary_muscles_gin_idx
            ON exercise_templates
            USING GIN (secondary_muscles)
            """,
            """
            DROP INDEX exercise_templates_secondary_muscles_gin_idx
            """
  end
end
