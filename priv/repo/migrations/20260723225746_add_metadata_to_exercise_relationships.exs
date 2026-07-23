defmodule Fittrack.Repo.Migrations.AddMetadataToExerciseRelationships do
  use Ecto.Migration

  def change do
    alter table(:exercise_variations) do
      add :similarity_score, :integer
      add :equipment_requirements, {:array, :string}, null: false, default: []
      add :difficulty_delta, :integer
    end

    alter table(:exercise_substitutions) do
      add :similarity_score, :integer
      add :equipment_requirements, {:array, :string}, null: false, default: []
      add :difficulty_delta, :integer
      add :reason_quality, :integer
    end

    create index(:exercise_variations, [:similarity_score])
    create index(:exercise_substitutions, [:similarity_score])
    create index(:exercise_substitutions, [:reason_quality])
  end
end
