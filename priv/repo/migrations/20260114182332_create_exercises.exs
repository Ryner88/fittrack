defmodule Fittrack.Repo.Migrations.CreateExercises do
  use Ecto.Migration

  def change do
    create table(:exercises) do
      add :name, :string
      add :primary_muscle, :string
      add :equipment, :string
      add :notes, :text
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:exercises, [:user_id])
  end
end
