defmodule Fittrack.Repo.Migrations.CreateMealPlans do
  use Ecto.Migration

  def change do
    create table(:meal_plans) do
      add :name, :string, null: false
      add :description, :text
      add :goal, :string, null: false, default: "maintain"
      add :daily_calories_target, :integer
      add :daily_protein_g_target, :integer
      add :daily_carbs_g_target, :integer
      add :daily_fats_g_target, :integer
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meal_plans, [:user_id])
  end
end
