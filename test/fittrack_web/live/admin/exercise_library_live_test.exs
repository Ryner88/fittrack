defmodule FittrackWeb.Admin.ExerciseLibraryLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fittrack.Training.ExerciseTemplateImporter

  setup :register_and_log_in_user

  test "renders internal exercise catalog metrics", %{conn: conn} do
    attrs =
      ExerciseTemplateImporter.normalize_exercise_from_wger(%{
        "id" => 8101,
        "translations" => [
          %{"language" => 2, "name" => "Goblet squat", "description" => "Squat pattern."}
        ],
        "muscles" => [%{"name_en" => "Quads"}],
        "equipment" => [%{"name" => "Kettlebell"}]
      })

    assert {:ok, :inserted, _template} = ExerciseTemplateImporter.upsert_template(attrs)

    {:ok, view, _html} = live(conn, ~p"/admin/exercises")

    assert has_element?(view, "#exercise-admin-metrics")
    assert has_element?(view, "#admin-exercise-template-list")
    assert has_element?(view, "#admin-exercise-library-link")
  end

  test "renders media provider attribution", %{conn: conn} do
    attrs =
      ExerciseTemplateImporter.normalize_exercise_from_wger(%{
        "id" => 8102,
        "translations" => [
          %{"language" => 2, "name" => "Attribution row", "description" => "Imported."}
        ],
        "muscles" => [%{"name_en" => "Chest"}],
        "equipment" => [%{"name" => "Body weight"}],
        "images" => [
          %{
            "id" => 9102,
            "image" => "https://wger.de/media/exercise-images/8102/main.jpg",
            "license_author" => "wger project"
          }
        ]
      })

    assert {:ok, :inserted, _template} = ExerciseTemplateImporter.upsert_template(attrs)

    {:ok, view, _html} = live(conn, ~p"/admin/exercises")

    assert render(view) =~ "wger project"
  end
end
