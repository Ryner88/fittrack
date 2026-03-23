defmodule FittrackWeb.NutritionLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fittrack.AccountsFixtures
  import Fittrack.NutritionFixtures

  test "dashboard shows and lists stats", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/nutrition")
    assert html =~ "Nutrition Dashboard"
  end

  test "can create a meal via LiveView flow", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    food = food_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/meals/new")

    assert has_element?(view, "#meal-form")

    view
    |> form("#food-library-form", %{
      "food_id" => to_string(food.id),
      "quantity" => "100",
      "unit" => "g"
    })
    |> render_submit()

    # Save meal with required name/eaten_at
    {:ok, _, _} =
      view
      |> form("#meal-form", %{
        "meal" => %{
          "name" => "Breakfast",
          "eaten_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/meals")

    assert render(view) =~ "Meal created successfully"
  end

  test "can create a meal plan via LiveView", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    food_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/meal-plans/new")

    assert has_element?(view, "#meal-plan-form")

    {:ok, _, _} =
      view
      |> form("#meal-plan-form", %{
        "meal_plan" => %{
          "name" => "Weekly",
          "goal" => "maintain",
          "daily_calories_target" => 2200
        }
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/meal-plans")

    assert render(view) =~ "Meal plan created successfully"
  end

  test "workout history shows calendar and counts", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/workout-history")
    assert html =~ "Workout History"
    assert html =~ "Month"
  end
end
