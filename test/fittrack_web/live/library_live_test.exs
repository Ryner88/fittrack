defmodule FittrackWeb.LibraryLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Repo
  alias Fittrack.Accounts.Scope
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseAlias
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle

  test "public exercise library renders without authentication and filters by alias search", %{
    conn: conn
  } do
    bench =
      template_fixture(name: "Barbell Bench Press", primary_muscle: "Chest", equipment: "Barbell")

    _squat =
      template_fixture(name: "Goblet Squat", primary_muscle: "Quads", equipment: "Kettlebell")

    alias_fixture(bench, "bb bench")

    {:ok, view, _html} = live(conn, ~p"/exercises")

    assert has_element?(view, "#exercise-library-filters-form")
    assert has_element?(view, "#exercise-library-results")

    view
    |> form("#exercise-library-filters-form", filters: %{search: "bb bench"})
    |> render_change()

    assert_patch(view, ~p"/exercises?search=bb+bench")
    assert has_element?(view, "#exercise-library-results")
    assert render(view) =~ "Barbell Bench Press"
    refute render(view) =~ "Goblet Squat"
  end

  test "exercise detail page shows aliases, muscles, equipment, tags, variations, and substitutions",
       %{
         conn: conn
       } do
    bench =
      template_fixture(
        name: "Barbell Bench Press",
        primary_muscle: "Chest",
        equipment: "Barbell",
        weighted_tags: ["horizontal_push"],
        training_style_tags: ["powerlifting"],
        notes: "Lower the bar with control."
      )

    incline = template_fixture(name: "Incline Bench Press", primary_muscle: "Chest")
    push_up = template_fixture(name: "Push-Up", primary_muscle: "Chest", equipment: "Bodyweight")
    alias_fixture(bench, "Bench")
    muscle_fixture(bench, "Chest")
    equipment_fixture(bench, "Barbell")

    assert {:ok, _variation} =
             Training.create_exercise_variation(bench, incline, %{relationship: "angle"})

    assert {:ok, _substitution} =
             Training.create_exercise_substitution(bench, push_up, %{
               reason: "home_training",
               priority: 1
             })

    {:ok, _view, html} = live(conn, ~p"/exercises/#{bench.slug}")

    assert html =~ "Barbell Bench Press"
    assert html =~ "Bench"
    assert html =~ "Chest"
    assert html =~ "Barbell"
    assert html =~ "Lower the bar with control."
    assert html =~ "Incline Bench Press"
    assert html =~ "Push-Up"
    assert html =~ "Horizontal push"
    assert html =~ "Powerlifting"
  end

  test "library index and detail use safe placeholders for noncached media", %{conn: conn} do
    template =
      template_fixture(
        name: "Stale Media Row",
        primary_muscle: "Back",
        equipment: "Cable",
        image_url: "https://wger.de/media/exercise-images/stale-row.jpg"
      )

    media_fixture(template, %{
      cache_status: "stale",
      local_path: nil,
      source_url: template.image_url,
      failure_reason: "stale URL"
    })

    {:ok, index_view, index_html} = live(conn, ~p"/exercises")
    assert has_element?(index_view, ~s(img[src="/exercise-template-images/#{template.id}"]))
    refute index_html =~ template.image_url

    {:ok, show_view, show_html} = live(conn, ~p"/exercises/#{template.slug}")
    assert has_element?(show_view, ~s(img[src="/exercise-template-images/#{template.id}"]))
    refute show_html =~ template.image_url
  end

  test "library index and detail render cached exercise media", %{conn: conn} do
    template =
      template_fixture(
        name: "Cached Row",
        primary_muscle: "Back",
        equipment: "Cable",
        image_url: "https://wger.de/media/exercise-images/remote.jpg"
      )

    media = media_fixture(template)

    {:ok, _index_view, index_html} = live(conn, ~p"/exercises")
    assert index_html =~ ~s(src="/exercise-media/#{media.id}")
    refute index_html =~ template.image_url

    {:ok, _show_view, show_html} = live(conn, ~p"/exercises/#{template.slug}")
    assert show_html =~ ~s(src="/exercise-media/#{media.id}")
    refute show_html =~ template.image_url
  end

  test "signed-in user can add an exercise detail page to an active workout", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    bench =
      template_fixture(name: "Barbell Bench Press", primary_muscle: "Chest", equipment: "Barbell")

    assert {:ok, workout} =
             Training.create_workout(scope, %{
               started_at: DateTime.utc_now() |> DateTime.truncate(:second)
             })

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/exercises/#{bench.slug}")

    assert has_element?(view, "#add-to-workout-panel")

    view
    |> form("#add-to-workout-form", workout: %{workout_id: Integer.to_string(workout.id)})
    |> render_submit()

    exercise = scope |> Training.list_exercises() |> List.first()

    assert_redirect(view, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")
  end

  test "signed-in user can start a new workout from an exercise detail page", %{conn: conn} do
    user = Fittrack.AccountsFixtures.user_fixture()
    scope = %Scope{user: user}

    bench =
      template_fixture(
        name: "Dumbbell Bench Press",
        primary_muscle: "Chest",
        equipment: "Dumbbell"
      )

    conn = log_in_user(conn, user)
    {:ok, view, _html} = live(conn, ~p"/exercises/#{bench.slug}")

    view
    |> form("#add-to-workout-form", workout: %{workout_id: "new", name: "Push Day"})
    |> render_submit()

    exercise = scope |> Training.list_exercises() |> List.first()
    workout = Training.get_active_workout(scope)

    assert workout.notes == "Push Day"
    assert_redirect(view, ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")
  end

  defp template_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          name: "Romanian Deadlift",
          primary_muscle: "Hamstrings",
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

  defp alias_fixture(template, name) do
    %ExerciseAlias{}
    |> ExerciseAlias.changeset(%{
      exercise_template_id: template.id,
      name: name,
      kind: "abbreviation",
      weight: 10
    })
    |> Repo.insert!()
  end

  defp muscle_fixture(template, name) do
    muscle =
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{name: name})
      |> Repo.insert!()

    %ExerciseTemplateMuscle{}
    |> ExerciseTemplateMuscle.changeset(%{
      exercise_template_id: template.id,
      exercise_muscle_id: muscle.id,
      role: "primary",
      position: 0
    })
    |> Repo.insert!()
  end

  defp equipment_fixture(template, name) do
    equipment =
      %ExerciseEquipment{}
      |> ExerciseEquipment.changeset(%{name: name})
      |> Repo.insert!()

    %ExerciseTemplateEquipment{}
    |> ExerciseTemplateEquipment.changeset(%{
      exercise_template_id: template.id,
      exercise_equipment_id: equipment.id,
      position: 0
    })
    |> Repo.insert!()
  end

  defp media_fixture(template, attrs \\ %{}) do
    %ExerciseMedia{}
    |> ExerciseMedia.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          kind: "image",
          source: "wger",
          source_id: "cached-#{template.id}",
          source_exercise_id: to_string(template.source_id),
          source_url: template.image_url || "https://wger.de/media/#{template.id}.jpg",
          cache_status: "cached",
          local_path: "#{template.id}/cached.jpg",
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
