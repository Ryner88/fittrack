defmodule FittrackWeb.Api.V1.WorkoutSetController do
  use FittrackWeb, :controller

  alias Fittrack.Training
  alias FittrackWeb.Api.V1.JSONHelpers

  def index(conn, %{"workout_id" => workout_id} = params) do
    case Training.get_workout(conn.assigns.current_scope, workout_id) do
      nil ->
        not_found(conn, "Workout not found")

      workout ->
        sets = Training.list_workout_sets(conn.assigns.current_scope, workout, params)
        json(conn, %{data: Enum.map(sets, &JSONHelpers.workout_set_json(&1, conn))})
    end
  end

  def create(conn, %{"workout_id" => workout_id} = params) do
    attrs = Map.get(params, "set", Map.delete(params, "workout_id"))

    with workout when not is_nil(workout) <-
           Training.get_workout(conn.assigns.current_scope, workout_id),
         {:ok, workout_set} <-
           Training.create_workout_set(conn.assigns.current_scope, workout, attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: JSONHelpers.workout_set_json(workout_set, conn)})
    else
      nil -> not_found(conn, "Workout not found")
      {:error, :invalid_exercise} -> invalid_exercise(conn)
      {:error, :unauthorized} -> forbidden(conn)
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs =
      params
      |> Map.get("set", params)
      |> Map.drop(["id", "workout_id"])

    with workout_set when not is_nil(workout_set) <-
           Training.get_workout_set(conn.assigns.current_scope, id),
         {:ok, workout_set} <-
           Training.update_workout_set(conn.assigns.current_scope, workout_set, attrs) do
      json(conn, %{data: JSONHelpers.workout_set_json(workout_set, conn)})
    else
      nil -> not_found(conn, "Set not found")
      {:error, :invalid_exercise} -> invalid_exercise(conn)
      {:error, :unauthorized} -> forbidden(conn)
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Training.get_workout_set(conn.assigns.current_scope, id) do
      nil ->
        not_found(conn, "Set not found")

      workout_set ->
        {:ok, _workout_set} = Training.delete_workout_set(conn.assigns.current_scope, workout_set)
        send_resp(conn, :no_content, "")
    end
  end

  defp invalid_exercise(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{exercise_id: ["does not belong to the authenticated user"]}})
  end

  defp not_found(conn, detail) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: detail}})
  end

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{errors: %{detail: "Forbidden"}})
  end

  defp validation_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: JSONHelpers.changeset_errors(changeset)})
  end
end
