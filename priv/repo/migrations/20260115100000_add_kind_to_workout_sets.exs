defmodule Fittrack.Repo.Migrations.AddKindToWorkoutSets do
  use Ecto.Migration

  def change do
    alter table(:workout_sets) do
      add :kind, :string, null: false, default: "normal"
    end
  end
end
