defmodule Fittrack.Repo.Migrations.CreateMeals do
  use Ecto.Migration

  def change do
    create table(:meals) do
      add :name, :string, null: false
      add :eaten_at, :utc_datetime, null: false
      add :notes, :text
      add :total_calories, :decimal, precision: 8, scale: 2
      add :total_protein_g, :decimal, precision: 8, scale: 2
      add :total_carbs_g, :decimal, precision: 8, scale: 2
      add :total_fats_g, :decimal, precision: 8, scale: 2
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meals, [:user_id])
    create index(:meals, [:eaten_at])
  end
end
