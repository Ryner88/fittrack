defmodule FittrackWeb.OneRepMaxLiveTest do
  use FittrackWeb.ConnCase

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures
  import Phoenix.LiveViewTest

  test "calculates estimated one rep max and percentage loads", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    exercise = exercise_fixture(scope, %{name: "Bench Press"})

    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/one-rep-max")

    assert has_element?(view, "#one-rep-max-form")
    assert has_element?(view, ~s(select[name="one_rep_max[exercise_id]"]))
    assert has_element?(view, "#one-rep-max-results")

    html =
      view
      |> form("#one-rep-max-form",
        one_rep_max: %{
          "exercise_id" => exercise.id,
          "weight" => "225",
          "reps" => "5",
          "bodyweight" => "160",
          "unit" => "lb"
        }
      )
      |> render_submit()

    assert html =~ "262.5 lb"
    assert html =~ "Bench Press"
    assert html =~ "Advanced"
    assert html =~ "Strength triples"
  end
end
