defmodule FittrackWeb.WorkoutHistoryLiveTest do
  use FittrackWeb.ConnCase

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures
  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Training

  test "top navigation labels completed workouts as History", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, ~s(a[href="/workout-history"]), "History")
    refute has_element?(view, ~s(a[href="/workouts"]), "Workouts")
    assert has_element?(view, "#header-start-workout-link")
    assert has_element?(view, "#profile-menu-button")
    assert has_element?(view, "#profile-settings-link")
    assert has_element?(view, "#profile-log-out-link")
    assert has_element?(view, "#command-bar")
    assert has_element?(view, "#command-bar-open")

    assert has_element?(
             view,
             ~s(a[data-command-item][href="/workouts/new"]),
             "Start empty workout"
           )

    assert has_element?(view, ~s(a[data-command-item][href="/workout-plans"]), "Start from plan")
    assert has_element?(view, ~s(a[data-command-item][href="/nutrition"]), "Nutrition")
    assert has_element?(view, ~s(a[data-command-item][href="/meals/new"]), "Log meal")
  end

  test "dashboard shows start and browse plan CTAs when no active workout exists", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard-start-workout-link")
    assert has_element?(view, "#dashboard-browse-plans-link")
    refute has_element?(view, "#dashboard-resume-workout-link")
  end

  test "dashboard and header show resume CTA when an active workout exists", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}

    {:ok, _active_workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard-resume-workout-link")
    assert has_element?(view, "#header-resume-workout-link")

    assert has_element?(
             view,
             ~s(a[data-command-item][href="/workouts/#{Training.get_active_workout(scope).id}"]),
             "Resume workout"
           )

    assert has_element?(
             view,
             ~s(a[data-command-item][href="/workouts/#{Training.get_active_workout(scope).id}"]),
             "Log set"
           )

    refute has_element?(view, "#dashboard-start-workout-link")
    refute has_element?(view, "#dashboard-browse-plans-link")
    refute has_element?(view, "#command-bar", "Start empty workout")
  end

  test "shows start and browse plan CTAs when no active workout exists", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/workout-history")

    assert has_element?(view, "#start-workout-link")
    assert has_element?(view, "#browse-plans-link")
    refute has_element?(view, "#resume-workout-link")
  end

  test "shows resume CTA when an active workout exists", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}

    {:ok, _active_workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-history")

    assert has_element?(view, "#resume-workout-link")
    refute has_element?(view, "#start-workout-link")
    refute has_element?(view, "#browse-plans-link")
  end

  test "calendar and selected day only count completed workouts", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    exercise = exercise_fixture(scope)
    today = Date.utc_today()
    started_at = today |> DateTime.new!(~T[12:00:00], "Etc/UTC")

    {:ok, active_workout} =
      Training.create_workout(scope, %{started_at: DateTime.add(started_at, 3600, :second)})

    {:ok, completed_workout} = Training.create_workout(scope, %{started_at: started_at})

    {:ok, _set} =
      Training.create_workout_set(scope, completed_workout, %{
        exercise_id: exercise.id,
        weight: "100",
        reps: "5",
        kind: "normal"
      })

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-history")

    view
    |> element(~s(button[phx-value-date="#{Date.to_iso8601(today)}"]))
    |> render_click()

    assert has_element?(view, "#history-workout-#{completed_workout.id}")
    refute has_element?(view, "#history-workout-#{active_workout.id}")
    assert has_element?(view, "#history-selected-day", "1 completed")
    assert has_element?(view, "#history-selected-day", "5 reps")
    assert has_element?(view, "#history-selected-day", "500 lbs")
  end
end
