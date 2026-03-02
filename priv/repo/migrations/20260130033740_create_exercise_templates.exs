defmodule Fittrack.Repo.Migrations.CreateExerciseTemplates do
  use Ecto.Migration

  def change do
    create table(:exercise_templates) do
      add :name, :string, null: false
      add :primary_muscle, :string
      add :equipment, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_templates, [:name])
    create index(:exercise_templates, [:primary_muscle])
    create index(:exercise_templates, [:equipment])

    # Optional: prevent exact duplicates (case-sensitive)
    create unique_index(:exercise_templates, [:name, :equipment])
  end
end
