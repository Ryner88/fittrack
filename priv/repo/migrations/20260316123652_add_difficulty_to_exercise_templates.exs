defmodule Fittrack.Repo.Migrations.AddDifficultyToExerciseTemplates do
  use Ecto.Migration

  def change do
    alter table(:exercise_templates) do
      add :difficulty, :string, default: "intermediate"
    end

    create index(:exercise_templates, [:difficulty])
  end
end
