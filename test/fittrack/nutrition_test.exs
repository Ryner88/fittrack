defmodule Fittrack.NutritionTest do
  use Fittrack.DataCase

  alias Fittrack.Nutrition

  import Fittrack.AccountsFixtures
  import Fittrack.NutritionFixtures

  describe "foods" do
    test "create/get food" do
      scope = user_scope_fixture()
      food = food_fixture(scope)

      assert Nutrition.get_food!(scope, food.id).id == food.id
      assert food.name == "Apple"
    end

    test "list_foods returns only user food" do
      scope = user_scope_fixture()
      food_fixture(scope)
      assert [%{}] = Nutrition.list_foods(scope)
    end
  end

  describe "meals" do
    test "create meal calculates totals" do
      scope = user_scope_fixture()

      meal = meal_fixture(scope)
      assert meal.total_calories == Decimal.new("52")
      assert has = Enum.any?(meal.meal_items, fn item -> item.food_name == "Apple" end)
      assert has
    end
  end

  describe "meal plans" do
    test "create meal plan with meals works" do
      scope = user_scope_fixture()
      plan = meal_plan_fixture(scope)

      assert plan.name == "Weekly plan"
      assert length(plan.meal_plan_meals) == 1
    end
  end
end
