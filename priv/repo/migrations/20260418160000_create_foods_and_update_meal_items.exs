defmodule Fittrack.Repo.Migrations.CreateFoodsAndUpdateMealItems do
  use Ecto.Migration

  def change do
    create table(:foods) do
      add :name, :string, null: false
      add :unit, :string, null: false, default: "g"
      add :unit_amount, :decimal, precision: 8, scale: 2, null: false, default: 100.0
      add :calories_per_unit, :decimal, precision: 8, scale: 2, null: false
      add :protein_per_unit, :decimal, precision: 8, scale: 2, default: 0.0
      add :carbs_per_unit, :decimal, precision: 8, scale: 2, default: 0.0
      add :fats_per_unit, :decimal, precision: 8, scale: 2, default: 0.0
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:foods, [:user_id])

    alter table(:meal_items) do
      add :food_id, references(:foods, on_delete: :nilify_all)
    end

    create index(:meal_items, [:food_id])
  end
end
