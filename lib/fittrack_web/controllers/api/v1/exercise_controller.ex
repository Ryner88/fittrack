defmodule FittrackWeb.Api.V1.ExerciseController do
  use FittrackWeb, :controller

  alias Fittrack.Training
  alias FittrackWeb.Api.V1.JSONHelpers

  def index(conn, params) do
    page =
      conn.assigns.current_scope
      |> Training.paginate_exercises(Map.put(params, "preload_source_template", true))

    json(conn, %{
      data: Enum.map(page.entries, &JSONHelpers.exercise_json(&1, conn)),
      pagination: JSONHelpers.pagination(page)
    })
  end

  def show(conn, %{"id" => id}) do
    case Training.get_exercise(conn.assigns.current_scope, id, preload_source_template: true) do
      nil ->
        not_found(conn, "Exercise not found")

      exercise ->
        json(conn, %{data: JSONHelpers.exercise_json(exercise, conn)})
    end
  end

  def create(conn, params) do
    attrs = Map.get(params, "exercise", params)

    case Training.create_exercise(conn.assigns.current_scope, attrs) do
      {:ok, exercise} ->
        exercise = Fittrack.Repo.preload(exercise, source_template: :media)

        conn
        |> put_status(:created)
        |> json(%{data: JSONHelpers.exercise_json(exercise, conn)})

      {:error, changeset} ->
        validation_error(conn, changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = Map.get(params, "exercise", Map.delete(params, "id"))

    with exercise when not is_nil(exercise) <-
           Training.get_exercise(conn.assigns.current_scope, id),
         {:ok, exercise} <- Training.update_exercise(conn.assigns.current_scope, exercise, attrs) do
      exercise = Fittrack.Repo.preload(exercise, source_template: :media)
      json(conn, %{data: JSONHelpers.exercise_json(exercise, conn)})
    else
      nil -> not_found(conn, "Exercise not found")
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Training.get_exercise(conn.assigns.current_scope, id) do
      nil ->
        not_found(conn, "Exercise not found")

      exercise ->
        {:ok, _exercise} = Training.delete_exercise(conn.assigns.current_scope, exercise)
        send_resp(conn, :no_content, "")
    end
  end

  def add_template(conn, %{"template_id" => template_id}) do
    case Training.add_template_to_user(conn.assigns.current_scope, template_id) do
      {:ok, exercise} ->
        exercise = Fittrack.Repo.preload(exercise, source_template: :media)

        conn
        |> put_status(:created)
        |> json(%{data: JSONHelpers.exercise_json(exercise, conn)})

      {:error, :not_found} ->
        not_found(conn, "Exercise template not found")

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{errors: %{detail: "Forbidden"}})
    end
  end

  defp not_found(conn, detail) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: detail}})
  end

  defp validation_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: JSONHelpers.changeset_errors(changeset)})
  end
end
