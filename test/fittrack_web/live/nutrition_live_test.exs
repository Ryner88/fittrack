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
    assert has_element?(view, "#food-library-form")

    html =
      view
      |> form("#food-library-form", %{
        "food_library" => %{
          "food_id" => to_string(food.id),
          "quantity" => "100",
          "unit" => "g"
        }
      })
      |> render_submit()

    assert html =~ "Apple"

    # Save meal with required name/eaten_at
    eaten_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")

    {:ok, _index_view, index_html} =
      view
      |> form("#meal-form", %{
        "meal" => %{
          "name" => "Breakfast",
          "eaten_at" => eaten_at
        }
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/meals")

    assert index_html =~ "Meal created successfully"
    assert index_html =~ "Breakfast"
  end

  test "can create a meal plan via LiveView", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    food_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/meal-plans/new")

    assert has_element?(view, "#meal-plan-form")

    {:ok, _index_view, index_html} =
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

    assert index_html =~ "Meal plan created successfully"
    assert index_html =~ "Weekly"
  end

  test "workout history shows calendar and counts", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/workout-history")
    assert html =~ "Workout History"
    assert html =~ "Month"
  end
end
