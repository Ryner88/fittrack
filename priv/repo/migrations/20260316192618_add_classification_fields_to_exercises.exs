defmodule Fittrack.Repo.Migrations.AddClassificationFieldsToExercises do
  use Ecto.Migration

  def change do
    alter table(:exercises) do
      add :movement_pattern, :string
      add :exercise_category, :string
      add :training_style_tags, {:array, :string}, default: []
      add :secondary_muscles, {:array, :string}, default: []
      add :source_template_id, references(:exercise_templates, on_delete: :nilify_all)
    end

    create index(:exercises, [:movement_pattern])
    create index(:exercises, [:exercise_category])
    create index(:exercises, [:source_template_id])

    execute """
            CREATE INDEX exercises_training_style_tags_gin_idx
            ON exercises
            USING GIN (training_style_tags)
            """,
            """
            DROP INDEX exercises_training_style_tags_gin_idx
            """

    execute """
            CREATE INDEX exercises_secondary_muscles_gin_idx
            ON exercises
            USING GIN (secondary_muscles)
            """,
            """
            DROP INDEX exercises_secondary_muscles_gin_idx
            """
  end
end
