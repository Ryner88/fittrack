defmodule Fittrack.Repo.Migrations.CreateMealPlanMeals do
  use Ecto.Migration

  def change do
    create table(:meal_plan_meals) do
      add :day_of_week, :integer, null: false
      add :meal_name, :string, null: false
      add :serving_count, :decimal, precision: 4, scale: 1, null: false, default: 1.0
      add :calories_per_serving, :decimal, precision: 8, scale: 2
      add :protein_g_per_serving, :decimal, precision: 8, scale: 2
      add :carbs_g_per_serving, :decimal, precision: 8, scale: 2
      add :fats_g_per_serving, :decimal, precision: 8, scale: 2
      add :meal_plan_id, references(:meal_plans, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meal_plan_meals, [:meal_plan_id])
    create index(:meal_plan_meals, [:day_of_week])
  end
end
