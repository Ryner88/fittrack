defmodule FittrackWeb.WorkoutLive.ShowTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseTemplate

  test "shows recently used and most logged exercise shortcuts", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}
    squat = exercise_fixture(scope, %{name: "Back Squat", primary_muscle: "Quads"})
    bench = exercise_fixture(scope, %{name: "Bench Press", primary_muscle: "Chest"})

    {:ok, historical_workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, _set} = workout_set_fixture(scope, historical_workout, squat)
    {:ok, _set} = workout_set_fixture(scope, historical_workout, bench)
    {:ok, _set} = workout_set_fixture(scope, historical_workout, bench)

    {:ok, workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/workouts/#{workout}")

    assert html =~ "Recently used"
    assert html =~ "Most logged"
    assert has_element?(view, "#recent-shortcut-exercise-#{bench.id}")

    view
    |> element("#recent-shortcut-exercise-#{bench.id}")
    |> render_click()

    assert has_element?(view, ~s(option[value="#{bench.id}"][selected]))
  end

  test "shows substitution suggestions for the selected exercise", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    bench =
      template_fixture(name: "Barbell Bench Press", primary_muscle: "Chest", equipment: "Barbell")

    dumbbell =
      template_fixture(
        name: "Dumbbell Bench Press",
        primary_muscle: "Chest",
        equipment: "Dumbbell"
      )

    assert {:ok, _substitution} =
             Training.create_exercise_substitution(bench, dumbbell, %{
               reason: "equipment",
               priority: 1
             })

    assert {:ok, exercise} = Training.add_template_to_user(scope, bench.id)

    {:ok, workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")

    assert html =~ "Can&#39;t do Barbell Bench Press?"
    assert html =~ "Dumbbell Bench Press"

    view
    |> element("#substitute-template-#{dumbbell.id}")
    |> render_click()

    substitute =
      scope |> Training.list_exercises() |> Enum.find(&(&1.name == "Dumbbell Bench Press"))

    assert substitute
    assert has_element?(view, ~s(option[value="#{substitute.id}"][selected]))
  end

  test "workout logging library rows render cached primary media", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    template =
      template_fixture(
        name: "Cable Row",
        primary_muscle: "Back",
        equipment: "Cable",
        image_url: "https://wger.de/media/exercise-images/row.jpg"
      )

    media = media_fixture(template)

    {:ok, workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = log_in_user(conn, user)
    {:ok, _view, html} = live(conn, ~p"/workouts/#{workout}")

    assert html =~ ~s(src="/exercise-media/#{media.id}")
    refute html =~ template.image_url
  end

  test "selected linked exercise shows cached form video without disrupting set entry", %{
    conn: conn
  } do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    template =
      template_fixture(name: "Video Row", primary_muscle: "Back", equipment: "Cable")

    media =
      media_fixture(template, %{
        kind: "video",
        source_id: "cached-video-#{template.id}",
        source_url: "https://wger.de/media/exercise-videos/row.mp4",
        cache_status: "cached",
        local_path: "#{template.id}/row.mp4",
        mime_type: "video/mp4",
        is_primary: true
      })

    {:ok, exercise} = Training.add_template_to_user(scope, template.id)
    workout = active_workout_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")

    assert has_element?(view, "#workout-set-form")
    assert has_element?(view, ~s(select[name="workout_set[exercise_id]"]))
    assert has_element?(view, ~s(input[name="workout_set[weight]"]))
    assert html =~ "Form video"
    assert html =~ ~s(href="/exercise-media/#{media.id}")
  end

  test "selected linked exercise shows safe external form video when video is remote-only", %{
    conn: conn
  } do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    template =
      template_fixture(name: "External Video Row", primary_muscle: "Back", equipment: "Cable")

    media_fixture(template, %{
      kind: "video",
      source_id: "external-video-#{template.id}",
      source_url: "https://wger.de/media/exercise-videos/external-row.mp4",
      cache_status: "remote_only",
      local_path: nil,
      mime_type: "video/mp4"
    })

    {:ok, exercise} = Training.add_template_to_user(scope, template.id)
    workout = active_workout_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, _view, html} = live(conn, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")

    assert html =~ "Form video"
    assert html =~ ~s(href="https://wger.de/media/exercise-videos/external-row.mp4")
    assert html =~ ~s(target="_blank")
    assert html =~ ~s(rel="noopener noreferrer")
  end

  test "selected linked exercise with no usable media shows fallback and no broken link", %{
    conn: conn
  } do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    template = template_fixture(name: "No Media Row", primary_muscle: "Back", equipment: "Cable")

    media_fixture(template, %{
      kind: "video",
      source_id: "stale-video-#{template.id}",
      source_url: "https://wger.de/media/exercise-videos/stale-row.mp4",
      cache_status: "stale",
      local_path: nil,
      mime_type: "video/mp4"
    })

    {:ok, exercise} = Training.add_template_to_user(scope, template.id)
    workout = active_workout_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")

    assert has_element?(view, "#workout-set-form")
    assert html =~ "No form reference available"
    refute html =~ "stale-row.mp4"
  end

  test "selected custom exercise without linked template renders safely", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}
    exercise = exercise_fixture(scope, %{name: "Custom Curl", primary_muscle: "Biceps"})
    workout = active_workout_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, html} = live(conn, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")

    assert has_element?(view, "#workout-set-form")
    assert html =~ "No form reference available"
  end

  defp exercise_fixture(scope, attrs) do
    attrs =
      Map.merge(
        %{name: "Exercise", primary_muscle: "Chest", equipment: "Barbell", notes: "Test"},
        attrs
      )

    {:ok, exercise} = Training.create_exercise(scope, attrs)
    exercise
  end

  defp workout_set_fixture(scope, workout, exercise) do
    Training.create_workout_set(scope, workout, %{
      exercise_id: exercise.id,
      weight: "100",
      reps: "5",
      kind: "normal"
    })
  end

  defp active_workout_fixture(scope) do
    {:ok, workout} =
      Training.create_workout(scope, %{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    workout
  end

  defp template_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          name: "Template",
          primary_muscle: "Chest",
          equipment: "Barbell",
          difficulty: "intermediate",
          exercise_category: "compound"
        },
        Map.new(attrs)
      )

    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(attrs)
    |> Repo.insert!()
  end

  defp media_fixture(template, attrs \\ %{}) do
    source_id = Map.get(attrs, :source_id, "workout-media-#{template.id}")

    %ExerciseMedia{}
    |> ExerciseMedia.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          kind: "image",
          source: "wger",
          source_id: source_id,
          source_url: template.image_url,
          cache_status: "cached",
          local_path: "#{template.id}/workout.jpg",
          mime_type: "image/jpeg",
          file_size: 12,
          is_primary: true
        },
        attrs
      )
    )
    |> Repo.insert!()
  end
end
