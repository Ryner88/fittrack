defmodule FittrackWeb.ExerciseTemplateImageControllerTest do
  use FittrackWeb.ConnCase

  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Repo

  setup do
    original_client = Application.get_env(:fittrack, :exercise_image_http_client)
    original_response = Application.get_env(:fittrack, :exercise_image_test_response)

    Application.put_env(
      :fittrack,
      :exercise_image_http_client,
      Fittrack.ExerciseImageHttpClientStub
    )

    on_exit(fn ->
      if original_client do
        Application.put_env(:fittrack, :exercise_image_http_client, original_client)
      else
        Application.delete_env(:fittrack, :exercise_image_http_client)
      end

      if original_response do
        Application.put_env(:fittrack, :exercise_image_test_response, original_response)
      else
        Application.delete_env(:fittrack, :exercise_image_test_response)
      end
    end)

    :ok
  end

  test "proxies template image bytes through the app", %{conn: conn} do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Push-up",
        primary_muscle: "Chest",
        equipment: "Bodyweight",
        image_url: "http://wger.de/media/exercise-images/1001/main.jpg"
      })
      |> Repo.insert()

    conn = get(conn, ~p"/exercise-template-images/#{template.id}")

    assert response(conn, 200) == "fake-image"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]

    assert_received {:exercise_image_request,
                     "https://wger.de/media/exercise-images/1001/main.jpg"}
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

  test "returns svg fallback when remote image request fails", %{conn: conn} do
    Application.put_env(:fittrack, :exercise_image_test_response, {:error, :econnrefused})

    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Broken Image",
        primary_muscle: "Back",
        equipment: "Cable",
        image_url: "https://wger.de/media/exercise-images/missing.jpg"
      })
      |> Repo.insert()

    conn = get(conn, ~p"/exercise-template-images/#{template.id}")

    assert response = response(conn, 200)
    assert response =~ "<svg"
    assert response =~ "Broken Image"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml; charset=utf-8"]
  end
end
