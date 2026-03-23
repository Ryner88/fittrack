defmodule Fittrack.Nutrition.MealPlanMeal do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Nutrition.MealPlan

  schema "meal_plan_meals" do
    field :day_of_week, :integer
    field :meal_name, :string
    field :serving_count, :decimal
    field :calories_per_serving, :decimal
    field :protein_g_per_serving, :decimal
    field :carbs_g_per_serving, :decimal
    field :fats_g_per_serving, :decimal

    belongs_to :meal_plan, MealPlan

    timestamps(type: :utc_datetime)
  end

  @days_of_week 0..6

  @doc false
  def changeset(meal_plan_meal, attrs) do
    meal_plan_meal
    |> cast(attrs, [
      :day_of_week,
      :meal_name,
      :serving_count,
      :calories_per_serving,
      :protein_g_per_serving,
      :carbs_g_per_serving,
      :fats_g_per_serving
    ])
    |> validate_required([:day_of_week, :meal_name, :serving_count])
    |> validate_inclusion(:day_of_week, @days_of_week)
    |> validate_number(:serving_count, greater_than: 0)
    |> validate_number(:calories_per_serving, greater_than_or_equal_to: 0)
    |> validate_number(:protein_g_per_serving, greater_than_or_equal_to: 0)
    |> validate_number(:carbs_g_per_serving, greater_than_or_equal_to: 0)
    |> validate_number(:fats_g_per_serving, greater_than_or_equal_to: 0)
  end

  def days_of_week, do: @days_of_week
end
