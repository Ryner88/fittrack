defmodule FittrackWeb.WorkoutPlanLive.GeneratorTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fittrack.TrainingFixtures
  import Fittrack.AccountsFixtures

  defp create_exercise(_) do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    exercise = exercise_fixture(scope)

    %{exercise: exercise, user: user}
  end

  describe "AI Workout Generator" do
    setup [:create_exercise]

    test "renders generator and creates a plan", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, generator_live, html} = live(conn, ~p"/workout-plans/generator")

      assert html =~ "AI Workout Generator"

      params = %{
        "goal" => "strength",
        "experience" => "beginner",
        "equipment" => ["Bodyweight"],
        "days_per_week" => "3"
      }

      assert generator_live
             |> form("#ai-workout-generator-form", ai_workout: params)
             |> render_submit()

      assert Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user}) != []
    end
  end
end
