defmodule FittrackWeb.Api.V1.MobileAPITest do
  use FittrackWeb.ConnCase, async: true

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures

  alias Fittrack.Training

  describe "mobile authentication" do
    test "rejects protected endpoints without a bearer token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/auth/me")

      assert json_response(conn, 401)["errors"]["detail"] == "Unauthorized"
    end

    test "logs in, returns current user, and revokes the token on logout", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/auth/login", %{
          "email" => user.email,
          "password" => valid_user_password()
        })

      assert %{"token" => token, "token_type" => "Bearer"} = json_response(conn, 200)["data"]

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/me")

      assert json_response(conn, 200)["data"]["email"] == user.email

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> delete(~p"/api/v1/auth/logout")

      assert response(conn, 204) == ""

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/me")

      assert json_response(conn, 401)
    end
  end

  describe "exercise library API" do
    setup %{conn: conn} do
      user = user_fixture()
      token = Fittrack.Accounts.generate_user_mobile_api_token(user)

      {:ok,
       conn: put_req_header(conn, "authorization", "Bearer #{token}"),
       scope: Fittrack.Accounts.Scope.for_user(user)}
    end

    test "lists shared exercise templates with only cached local media URLs", %{conn: conn} do
      {:ok, template} =
        Training.create_exercise_template(%{
          "name" => "Barbell Back Squat",
          "primary_muscle" => "Quads",
          "equipment" => "Barbell",
          "difficulty" => "intermediate"
        })

      {:ok, _other_template} =
        Training.create_exercise_template(%{
          "name" => "Lat Pulldown",
          "primary_muscle" => "Back",
          "equipment" => "Cable",
          "difficulty" => "beginner"
        })

      {:ok, media} =
        Training.upsert_exercise_media(template, %{
          kind: "image",
          source: "wger",
          source_id: "squat-1",
          source_url: "https://example.invalid/squat.png",
          local_path: "exercise_media/squat.png",
          cache_status: "cached",
          mime_type: "image/png",
          file_size: 42
        })

      conn = get(conn, ~p"/api/v1/exercise-templates", %{"search" => "squat", "per_page" => "1"})

      assert %{"data" => [template_json], "pagination" => %{"total_count" => 1}} =
               json_response(conn, 200)

      assert template_json["id"] == template.id
      assert [%{"id" => media_id, "url" => media_url}] = template_json["media"]
      assert media_id == media.id
      assert media_url == "/exercise-media/#{media.id}"
      refute Map.has_key?(List.first(template_json["media"]), "source_url")
    end

    test "adds a shared template to the authenticated user's exercise library", %{
      conn: conn,
      scope: scope
    } do
      {:ok, template} =
        Training.create_exercise_template(%{
          "name" => "Dumbbell Row",
          "primary_muscle" => "Back",
          "equipment" => "Dumbbell"
        })

      conn = post(conn, ~p"/api/v1/exercise-templates/#{template.id}/add")

      assert %{"source_template_id" => source_template_id, "name" => "Dumbbell Row"} =
               json_response(conn, 201)["data"]

      assert source_template_id == template.id
      assert [_exercise] = Training.list_exercises(scope)
    end
  end

  describe "workout, set, and history API" do
    setup %{conn: conn} do
      user = user_fixture()
      token = Fittrack.Accounts.generate_user_mobile_api_token(user)
      scope = Fittrack.Accounts.Scope.for_user(user)
      exercise = exercise_fixture(scope, %{name: "Bench Press", equipment: "Barbell"})

      {:ok,
       conn: put_req_header(conn, "authorization", "Bearer #{token}"),
       scope: scope,
       exercise: exercise}
    end

    test "creates a workout, logs a set, and exposes it in history", %{
      conn: conn,
      exercise: exercise
    } do
      started_at = DateTime.utc_now(:second) |> DateTime.add(-3600, :second)

      conn =
        post(conn, ~p"/api/v1/workouts", %{
          "started_at" => DateTime.to_iso8601(started_at),
          "notes" => "Upper body"
        })

      assert %{"id" => workout_id, "status" => "active"} = json_response(conn, 201)["data"]

      conn =
        build_conn()
        |> put_req_header("authorization", get_req_header(conn, "authorization") |> List.first())
        |> post(~p"/api/v1/workouts/#{workout_id}/sets", %{
          "exercise_id" => exercise.id,
          "weight" => "135",
          "reps" => 5,
          "kind" => "working_set"
        })

      assert %{"exercise_id" => exercise_id, "weight" => "135", "reps" => 5} =
               json_response(conn, 201)["data"]

      assert exercise_id == exercise.id

      history_conn =
        build_conn()
        |> put_req_header("authorization", get_req_header(conn, "authorization") |> List.first())
        |> get(~p"/api/v1/history", %{
          "start_date" => Date.to_iso8601(Date.utc_today()),
          "end_date" => Date.to_iso8601(Date.utc_today())
        })

      assert [%{"id" => ^workout_id, "status" => "completed", "sets" => [_set]}] =
               json_response(history_conn, 200)["data"]
    end

    test "rejects sets for another user's exercise", %{conn: conn} do
      other_scope = user_scope_fixture()
      other_exercise = exercise_fixture(other_scope, %{name: "Private Curl"})

      workout_conn =
        post(conn, ~p"/api/v1/workouts", %{
          "started_at" => DateTime.to_iso8601(DateTime.utc_now(:second))
        })

      workout_id = json_response(workout_conn, 201)["data"]["id"]

      conn =
        build_conn()
        |> put_req_header("authorization", get_req_header(conn, "authorization") |> List.first())
        |> post(~p"/api/v1/workouts/#{workout_id}/sets", %{
          "exercise_id" => other_exercise.id,
          "weight" => "20",
          "reps" => 10,
          "kind" => "normal"
        })

      assert json_response(conn, 422)["errors"]["exercise_id"] == [
               "does not belong to the authenticated user"
             ]
    end
  end
end
