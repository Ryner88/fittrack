defmodule FittrackWeb.WorkoutLive.NewTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Training
  alias Fittrack.Training.Workout

  setup :register_and_log_in_user

  test "creates a workout from string-keyed form params", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/workouts/new")

    view
    |> form("#workout-form",
      workout: %{
        "started_at" => "2026-08-02T12:30",
        "notes" => "Started from LiveView form"
      }
    )
    |> render_submit()

    workout = Training.get_active_workout(%Scope{user: user})

    assert_redirect(view, ~p"/workouts/#{workout}")
    assert workout.lifecycle_state == Workout.active_state()
    assert workout.notes == "Started from LiveView form"
  end
end
