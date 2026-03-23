defmodule Fittrack.NutritionFixtures do
  @moduledoc """
  Test helpers for the Fittrack.Nutrition context.
  """

  alias Fittrack.Nutrition

  def food_fixture(scope, attrs \\ %{}) do
    params =
      Enum.into(attrs, %{
        "name" => "Apple",
        "unit" => "g",
        "unit_amount" => Decimal.new("100"),
        "calories_per_unit" => Decimal.new("52"),
        "protein_per_unit" => Decimal.new("0.26"),
        "carbs_per_unit" => Decimal.new("14"),
        "fats_per_unit" => Decimal.new("0.17")
      })

    {:ok, food} = Nutrition.create_food(scope, params)
    food
  end

  def meal_fixture(scope, attrs \\ %{}) do
    defaults = %{
      "name" => "Test Meal",
      "eaten_at" => DateTime.utc_now(),
      "meal_items" => [
        %{
          "meal_name" => "Apple",
          "quantity" => "100",
          "calories" => Decimal.new("52"),
          "protein_g" => Decimal.new("0.26"),
          "carbs_g" => Decimal.new("14"),
          "fats_g" => Decimal.new("0.17")
        }
      ]
    }

    attrs = Map.merge(defaults, attrs)

    {:ok, meal} = Nutrition.create_meal(scope, attrs)
    meal
  end

  def meal_plan_fixture(scope, attrs \\ %{}) do
    defaults = %{
      "name" => "Weekly plan",
      "goal" => "maintain",
      "daily_calories_target" => 2000,
      "meal_plan_meals" => [
        %{
          "day_of_week" => 0,
          "meal_name" => "Breakfast",
          "serving_count" => "1",
          "calories_per_serving" => "300",
          "protein_g_per_serving" => "15",
          "carbs_g_per_serving" => "40",
          "fats_g_per_serving" => "10"
        }
      ]
    }

    attrs = Map.merge(defaults, attrs)

    {:ok, meal_plan} = Nutrition.create_meal_plan(scope, attrs)
    meal_plan
  end
end
