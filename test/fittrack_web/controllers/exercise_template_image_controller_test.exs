defmodule FittrackWeb.ExerciseTemplateImageControllerTest do
  use FittrackWeb.ConnCase

  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Repo

  setup do
    original_root = Application.get_env(:fittrack, :exercise_media_storage_root)

    root =
      Path.join(
        System.tmp_dir!(),
        "fittrack-controller-media-#{System.unique_integer([:positive])}"
      )

    Application.put_env(:fittrack, :exercise_media_storage_root, root)

    on_exit(fn ->
      if original_root do
        Application.put_env(:fittrack, :exercise_media_storage_root, original_root)
      else
        Application.delete_env(:fittrack, :exercise_media_storage_root)
      end
    end)

    %{storage_root: root}
  end

  test "serves cached template image bytes through the app", %{conn: conn, storage_root: root} do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Push-up",
        primary_muscle: "Chest",
        equipment: "Bodyweight"
      })
      |> Repo.insert()

    local_path = "#{template.id}/main.jpg"
    File.mkdir_p!(Path.dirname(Path.join(root, local_path)))
    File.write!(Path.join(root, local_path), "cached-image")

    {:ok, media} =
      %ExerciseMedia{}
      |> ExerciseMedia.changeset(%{
        exercise_template_id: template.id,
        kind: "image",
        source: "wger",
        source_id: "1001",
        source_url: "https://wger.de/media/exercise-images/1001/main.jpg",
        cache_status: "cached",
        local_path: local_path,
        mime_type: "image/jpeg",
        file_size: 12,
        is_primary: true
      })
      |> Repo.insert()

    conn = get(conn, ~p"/exercise-template-images/#{template.id}")

    assert response(conn, 200) == "cached-image"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]

    media_conn = get(build_conn(), ~p"/exercise-media/#{media.id}")
    assert response(media_conn, 200) == "cached-image"
  end

  test "returns svg fallback when template has no image", %{conn: conn} do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Squat",
        primary_muscle: "Legs",
        equipment: "Barbell"
      })
      |> Repo.insert()

    conn = get(conn, ~p"/exercise-template-images/#{template.id}")

    assert response = response(conn, 200)
    assert response =~ "<svg"
    assert response =~ "Squat"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml; charset=utf-8"]
  end

  test "returns svg fallback when cached file is missing", %{conn: conn} do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Broken Image",
        primary_muscle: "Back",
        equipment: "Cable"
      })
      |> Repo.insert()

    {:ok, _media} =
      %ExerciseMedia{}
      |> ExerciseMedia.changeset(%{
        exercise_template_id: template.id,
        kind: "image",
        source: "wger",
        source_id: "missing",
        source_url: "https://wger.de/media/exercise-images/missing.jpg",
        cache_status: "cached",
        local_path: "#{template.id}/missing.jpg",
        mime_type: "image/jpeg",
        file_size: 12,
        is_primary: true
      })
      |> Repo.insert()

    conn = get(conn, ~p"/exercise-template-images/#{template.id}")

    assert response = response(conn, 200)
    assert response =~ "<svg"
    assert response =~ "Broken Image"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml; charset=utf-8"]
  end
end
