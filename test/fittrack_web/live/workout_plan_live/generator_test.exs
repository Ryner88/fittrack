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
      assert html =~ "Training Split"
      assert html =~ "Available Equipment"

      params = %{
        "primary_goal" => "strength",
        "secondary_goal" => "endurance",
        "training_styles" => ["strength", "mobility"],
        "training_split" => ["upper_lower", "hybrid"],
        "experience" => "beginner",
        "equipment" => ["bodyweight", "dumbbell"],
        "days_per_week" => "3"
      }

      assert generator_live
             |> form("#ai-workout-generator-form", ai_workout: params)
             |> render_submit()

      [plan | _] = Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user})
      assert plan.primary_goal == "strength"
      assert plan.secondary_goal == "endurance"
      assert plan.training_styles == ["strength", "mobility"]
      assert plan.training_split == ["upper_lower", "hybrid"]
    end

    test "rejects duplicate goal selections", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, generator_live, _html} = live(conn, ~p"/workout-plans/generator")

      params = %{
        "primary_goal" => "strength",
        "secondary_goal" => "strength",
        "training_styles" => ["strength"],
        "training_split" => ["full_body"],
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3"
      }

      html =
        generator_live
        |> form("#ai-workout-generator-form", ai_workout: params)
        |> render_submit()

      assert html =~ "Each goal must be unique."
      assert Fittrack.Training.list_workout_plans(%Fittrack.Accounts.Scope{user: user}) == []
    end
  end
end
