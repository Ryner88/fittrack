defmodule FittrackWeb.WorkoutLive.IndexTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.Workout

  test "draft workouts stay out of the completed workout stream", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}
    exercise = exercise_fixture(scope)

    {:ok, completed_workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
      })

    {:ok, _set} =
      Training.create_workout_set(scope, completed_workout, %{
        exercise_id: exercise.id,
        weight: "100",
        reps: "5",
        kind: "normal"
      })

    {:ok, completed_workout} = Training.complete_workout(scope, completed_workout)

    draft =
      draft_workout_fixture(
        scope,
        DateTime.utc_now() |> DateTime.add(-1800, :second) |> DateTime.truncate(:second)
      )

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/workouts")

    assert has_element?(view, "#in_progress_workouts-#{draft.id}")
    refute has_element?(view, "#completed_workouts-#{draft.id}")
    assert has_element?(view, "#completed_workouts-#{completed_workout.id}")
    assert has_element?(view, "#in_progress_workouts-#{draft.id}", "Draft")
    assert has_element?(view, "#in_progress_workouts-#{draft.id} a", "Start workout")
  end

  defp exercise_fixture(scope) do
    {:ok, exercise} =
      Training.create_exercise(scope, %{
        name: "Bench Press",
        primary_muscle: "Chest",
        equipment: "Barbell",
        notes: "Test"
      })

    exercise
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
