defmodule Fittrack.Repo.Migrations.AddExtendedNutritionFields do
  use Ecto.Migration

  def change do
    alter table(:foods) do
      add :fiber_per_unit, :decimal, precision: 8, scale: 2
      add :sugar_per_unit, :decimal, precision: 8, scale: 2
      add :sodium_mg_per_unit, :decimal, precision: 10, scale: 2
      add :micronutrients, :map
    end

    alter table(:meal_items) do
      add :fiber_g, :decimal, precision: 8, scale: 2
      add :sugar_g, :decimal, precision: 8, scale: 2
      add :sodium_mg, :decimal, precision: 10, scale: 2
      add :micronutrients, :map
    end
  end
end
