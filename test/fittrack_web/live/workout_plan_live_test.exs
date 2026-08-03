defmodule FittrackWeb.WorkoutPlanLiveTest do
  use FittrackWeb.ConnCase

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures
  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.Workout

  test "plans page presents reusable workout templates", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    plan = workout_plan_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-plans")

    assert has_element?(view, "h1", "Workout Plans")

    assert has_element?(
             view,
             "p",
             "Create and manage reusable workout templates for consistent training."
           )

    assert has_element?(view, ~s(a[href="/workout-plans/generator"]), "AI Generator")
    assert has_element?(view, ~s(a[href="/workout-plans/new"]), "Create plan")
    assert has_element?(view, "#workout-plan-#{plan.id}", plan.name)
    assert has_element?(view, "#workout-plan-#{plan.id}", "Strength")
    assert has_element?(view, "#workout-plan-#{plan.id}", "2 days per week")
    assert has_element?(view, "#workout-plan-#{plan.id}", "2 exercises")
    assert has_element?(view, "#workout-plan-#{plan.id}", "Start from plan")
    assert has_element?(view, "#workout-plan-#{plan.id}", "Edit")
    assert has_element?(view, "#workout-plan-#{plan.id}", "Duplicate")
    refute has_element?(view, "#workout-plan-#{plan.id}", "Repeat")
    refute has_element?(view, "#workout-plan-#{plan.id}", "Browse plans")
  end

  test "starts a workout from a plan", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    plan = workout_plan_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-plans")

    {:ok, _show_view, _html} =
      view
      |> element(~s(#workout-plan-#{plan.id} button[phx-click="start_session"]))
      |> render_click()
      |> follow_redirect(conn)

    assert Training.get_active_workout(scope).notes == "Started from plan: #{plan.name}"
    assert Training.get_active_workout(scope).workout_sets == []
    assert Training.count_workouts(scope) == 0
  end

  test "plans page redirects to an existing draft instead of crashing when starting a plan", %{
    conn: conn
  } do
    user = user_fixture()
    scope = %Scope{user: user}
    plan = workout_plan_fixture(scope)
    draft = draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-plans")

    {:ok, _show_view, html} =
      view
      |> element(~s(#workout-plan-#{plan.id} button[phx-click="start_session"]))
      |> render_click()
      |> follow_redirect(conn, ~p"/workouts/#{draft}")

    assert html =~ "You already have an open workout."
  end

  test "plan show redirects to an existing draft instead of crashing when starting a plan", %{
    conn: conn
  } do
    user = user_fixture()
    scope = %Scope{user: user}
    plan = workout_plan_fixture(scope)
    draft = draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-plans/#{plan}")

    {:ok, _show_view, html} =
      view
      |> element(~s(button[phx-click="start_session"]))
      |> render_click()
      |> follow_redirect(conn, ~p"/workouts/#{draft}")

    assert html =~ "You already have an open workout."
  end

  test "new workout plan form renders with an empty exercise list", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/workout-plans/new")

    assert has_element?(view, "#workout-plan-form")
    assert has_element?(view, "#exercise-library")
    assert has_element?(view, "#drop-zone-Monday")
  end

  defp draft_workout_fixture(scope, started_at) do
    %Workout{}
    |> Workout.lifecycle_changeset(%{
      started_at: started_at,
      lifecycle_state: Workout.draft_state()
    })
    |> Ecto.Changeset.put_change(:user_id, scope.user.id)
    |> Repo.insert!()
  end
end
