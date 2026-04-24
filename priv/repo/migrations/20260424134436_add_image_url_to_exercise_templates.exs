defmodule Fittrack.Repo.Migrations.AddImageUrlToExerciseTemplates do
  use Ecto.Migration

  def change do
    alter table(:exercise_templates) do
      add :image_url, :string
    end
  end
end
