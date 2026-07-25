defmodule FittrackWeb.Api.V1.ExerciseTemplateController do
  use FittrackWeb, :controller

  alias Fittrack.Training
  alias FittrackWeb.Api.V1.JSONHelpers

  def index(conn, params) do
    page = Training.paginate_exercise_templates(params)

    json(conn, %{
      data: Enum.map(page.entries, &JSONHelpers.exercise_template_json(&1, conn)),
      pagination: JSONHelpers.pagination(page)
    })
  end

  def show(conn, %{"id" => id}) do
    case Training.get_exercise_template(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Exercise template not found"}})

      template ->
        json(conn, %{data: JSONHelpers.exercise_template_json(template, conn)})
    end
  end
end
