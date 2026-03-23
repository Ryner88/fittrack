defmodule Fittrack.Repo.Migrations.CreateMealItems do
  use Ecto.Migration

  def change do
    create table(:meal_items) do
      add :quantity, :decimal, precision: 8, scale: 2, null: false
      add :unit, :string, null: false, default: "g"
      add :calories, :decimal, precision: 8, scale: 2
      add :protein_g, :decimal, precision: 8, scale: 2
      add :carbs_g, :decimal, precision: 8, scale: 2
      add :fats_g, :decimal, precision: 8, scale: 2
      add :food_name, :string, null: false
      add :meal_id, references(:meals, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meal_items, [:meal_id])
  end
end
