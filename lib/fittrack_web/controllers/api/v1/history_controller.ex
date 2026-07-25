defmodule FittrackWeb.Api.V1.HistoryController do
  use FittrackWeb, :controller

  alias Fittrack.Training
  alias FittrackWeb.Api.V1.JSONHelpers

  def index(conn, params) do
    with {:ok, start_date, end_date} <- date_range(params) do
      workouts =
        Training.list_completed_workouts_in_date_range(
          conn.assigns.current_scope,
          start_date,
          end_date
        )

      json(conn, %{
        data: Enum.map(workouts, &JSONHelpers.workout_json(&1, conn)),
        meta: %{
          start_date: Date.to_iso8601(start_date),
          end_date: Date.to_iso8601(end_date)
        }
      })
    else
      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{date: ["must use ISO8601 YYYY-MM-DD dates"]}})
    end
  end

  def dates(conn, _params) do
    dates =
      conn.assigns.current_scope
      |> Training.list_completed_workout_dates()
      |> Enum.map(&Date.to_iso8601/1)

    json(conn, %{data: dates})
  end

  defp date_range(params) do
    today = Date.utc_today()

    with {:ok, start_date} <- parse_date(Map.get(params, "start_date"), Date.add(today, -30)),
         {:ok, end_date} <- parse_date(Map.get(params, "end_date"), today) do
      {:ok, start_date, end_date}
    end
  end

  defp parse_date(nil, default), do: {:ok, default}
  defp parse_date("", default), do: {:ok, default}

  defp parse_date(value, _default) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end
end
