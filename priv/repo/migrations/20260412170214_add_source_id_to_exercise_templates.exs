defmodule Fittrack.Repo.Migrations.AddSourceIdToExerciseTemplates do
  use Ecto.Migration

  def change do
    alter table(:exercise_templates) do
      add :source_id, :integer
    end

    create unique_index(:exercise_templates, [:source_id], where: "source_id IS NOT NULL")
  end
end
