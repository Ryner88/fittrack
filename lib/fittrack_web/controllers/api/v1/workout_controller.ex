defmodule FittrackWeb.Api.V1.WorkoutController do
  use FittrackWeb, :controller

  alias Fittrack.Training
  alias FittrackWeb.Api.V1.JSONHelpers

  def index(conn, params) do
    page = Training.paginate_workouts(conn.assigns.current_scope, params)

    json(conn, %{
      data: Enum.map(page.entries, &JSONHelpers.workout_json(&1, conn)),
      pagination: JSONHelpers.pagination(page)
    })
  end

  def active(conn, _params) do
    workouts = Training.list_active_workouts(conn.assigns.current_scope)

    json(conn, %{
      data: Enum.map(workouts, &JSONHelpers.workout_json(&1, conn))
    })
  end

  def create(conn, params) do
    attrs = Map.get(params, "workout", params)

    case Training.create_workout(conn.assigns.current_scope, attrs) do
      {:ok, workout} ->
        workout = Training.get_workout(conn.assigns.current_scope, workout.id)

        conn
        |> put_status(:created)
        |> json(%{data: JSONHelpers.workout_json(workout, conn)})

      {:error, changeset} ->
        validation_error(conn, changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    case Training.get_workout(conn.assigns.current_scope, id) do
      nil -> not_found(conn, "Workout not found")
      workout -> json(conn, %{data: JSONHelpers.workout_json(workout, conn)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = Map.get(params, "workout", Map.delete(params, "id"))

    with workout when not is_nil(workout) <- Training.get_workout(conn.assigns.current_scope, id),
         {:ok, workout} <- Training.update_workout(conn.assigns.current_scope, workout, attrs) do
      workout = Training.get_workout(conn.assigns.current_scope, workout.id)
      json(conn, %{data: JSONHelpers.workout_json(workout, conn)})
    else
      nil -> not_found(conn, "Workout not found")
      {:error, :unauthorized} -> forbidden(conn)
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Training.get_workout(conn.assigns.current_scope, id) do
      nil ->
        not_found(conn, "Workout not found")

      workout ->
        {:ok, _workout} = Training.delete_workout(conn.assigns.current_scope, workout)
        send_resp(conn, :no_content, "")
    end
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
