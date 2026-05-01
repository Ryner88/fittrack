defmodule FittrackWeb.ExerciseTemplateImageControllerTest do
  use FittrackWeb.ConnCase

  import Fittrack.AccountsFixtures

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
    user = user_fixture()

    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Push-up",
        primary_muscle: "Chest",
        equipment: "Bodyweight",
        image_url: "http://wger.de/media/exercise-images/1001/main.jpg"
      })
      |> Repo.insert()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/exercise-template-images/#{template.id}")

    assert response(conn, 200) == "fake-image"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]

    assert_received {:exercise_image_request,
                     "https://wger.de/media/exercise-images/1001/main.jpg"}
  end

  test "returns not found when template has no image", %{conn: conn} do
    user = user_fixture()

    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Squat",
        primary_muscle: "Legs",
        equipment: "Barbell"
      })
      |> Repo.insert()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/exercise-template-images/#{template.id}")

    assert response(conn, 404) == "Not Found"
  end
end
