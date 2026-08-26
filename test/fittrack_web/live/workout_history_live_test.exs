defmodule FittrackWeb.WorkoutHistoryLiveTest do
  use FittrackWeb.ConnCase

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures
  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.Workout

  test "top navigation labels completed workouts as History", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, ~s(a[href="/workout-history"]), "History")
    refute has_element?(view, ~s(a[href="/workouts"]), "Workouts")
    assert has_element?(view, "#header-start-workout-link")
    assert has_element?(view, "#mobile-menu-button")
    assert has_element?(view, "#mobile-primary-navigation")
    assert has_element?(view, "#mobile-start-workout-link")
    assert has_element?(view, "#mobile-command-bar-open")
    assert has_element?(view, "#mobile-dashboard-link")
    assert has_element?(view, "#mobile-nutrition-link")
    assert has_element?(view, "#mobile-library-link")
    assert has_element?(view, "#mobile-my-exercises-link")
    assert has_element?(view, "#mobile-plans-link")
    assert has_element?(view, "#mobile-history-link")
    assert has_element?(view, "#mobile-one-rep-max-link")
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
    assert has_element?(view, "#mobile-resume-workout-link")

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

  test "dashboard and header show resume CTA when a draft workout exists", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    draft = draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard-resume-workout-link")
    assert has_element?(view, "#header-resume-workout-link")
    assert has_element?(view, "#mobile-resume-workout-link")

    assert has_element?(
             view,
             ~s(a[data-command-item][href="/workouts/#{draft.id}"]),
             "Resume workout"
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

  test "shows resume CTA when a draft workout exists", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    draft = draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workout-history")

    assert has_element?(view, "#resume-workout-link")
    assert has_element?(view, ~s(a[href="/workouts/#{draft.id}"]), "Resume workout")
    refute has_element?(view, "#start-workout-link")
    refute has_element?(view, "#browse-plans-link")
  end

  test "calendar and selected day only count completed workouts", %{conn: conn} do
    user = user_fixture()
    scope = %Scope{user: user}
    exercise = exercise_fixture(scope)
    today = Date.utc_today()
    started_at = today |> DateTime.new!(~T[12:00:00], "Etc/UTC")

    {:ok, completed_workout} = Training.create_workout(scope, %{started_at: started_at})

    {:ok, _set} =
      Training.create_workout_set(scope, completed_workout, %{
        exercise_id: exercise.id,
        weight: "100",
        reps: "5",
        kind: "normal"
      })

    {:ok, completed_workout} = Training.complete_workout(scope, completed_workout)

    {:ok, active_workout} =
      Training.create_workout(scope, %{started_at: DateTime.add(started_at, 3600, :second)})

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

  test "custom exercise secondary muscles flow into completed workout history", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    today = Date.utc_today()

    {:ok, exercise_view, _html} = live(conn, ~p"/my-exercises/new")

    exercise_view
    |> form("#exercise-form",
      exercise: %{
        "name" => "Goblet Squat",
        "primary_muscle" => "Quads",
        "secondary_muscles" => ["Glutes", "Calves"],
        "equipment" => "Kettlebell",
        "notes" => "Full flow regression coverage"
      }
    )
    |> render_submit()

    assert_redirect(exercise_view, ~p"/my-exercises")

    scope = %Scope{user: user}
    exercise = Enum.find(Training.list_exercises(scope), &(&1.name == "Goblet Squat"))
    assert exercise.secondary_muscles == ["Glutes", "Calves"]

    {:ok, new_workout_view, _html} = live(conn, ~p"/workouts/new")

    new_workout_view
    |> form("#workout-form",
      workout: %{
        "started_at" => "#{Date.to_iso8601(today)}T12:30",
        "notes" => "Custom exercise regression"
      }
    )
    |> render_submit()

    workout = Training.get_active_workout(scope)
    assert_redirect(new_workout_view, ~p"/workouts/#{workout}")

    {:ok, workout_view, _html} = live(conn, ~p"/workouts/#{workout}")

    workout_view
    |> form("#workout-set-form",
      workout_set: %{
        "exercise_id" => exercise.id,
        "kind" => "normal",
        "weight" => "40",
        "reps" => "10"
      }
    )
    |> render_submit()

    assert has_element?(workout_view, "#workout-sets", "Goblet Squat")
    assert has_element?(workout_view, "#performed-set-summary", "1")
    assert has_element?(workout_view, "#performed-volume-summary", "400 lbs")

    workout_view
    |> element("#finish-workout-button")
    |> render_click()

    assert_redirect(workout_view, ~p"/workout-history")

    completed_workout = Training.get_workout!(scope, workout.id)
    assert completed_workout.lifecycle_state == Workout.completed_state()

    summaries = Training.list_workout_muscle_summaries(scope, completed_workout)
    assert length(summaries) == 3
    assert muscle_summary(summaries, "primary", "quads") == {"Quads", 1, 10, "400"}
    assert muscle_summary(summaries, "secondary", "glutes") == {"Glutes", 1, 10, "400"}
    assert muscle_summary(summaries, "secondary", "calves") == {"Calves", 1, 10, "400"}

    {:ok, history_view, _html} = live(conn, ~p"/workout-history")

    history_view
    |> element(~s(button[phx-value-date="#{Date.to_iso8601(today)}"]))
    |> render_click()

    assert has_element?(history_view, "#history-workout-#{completed_workout.id}")
    assert has_element?(history_view, "#history-selected-day", "1 sets")
    assert has_element?(history_view, "#history-selected-day", "10 reps")
    assert has_element?(history_view, "#history-selected-day", "400 lbs")
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

  defp muscle_summary(summaries, role, token) do
    summary = Enum.find(summaries, &(&1.role == role and &1.muscle_token == token))
    volume = summary.volume |> Decimal.normalize() |> Decimal.to_string(:normal)
    {summary.muscle_name, summary.sets, summary.reps, volume}
  end
end
