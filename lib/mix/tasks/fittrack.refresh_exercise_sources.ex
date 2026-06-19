defmodule Mix.Tasks.Fittrack.RefreshExerciseSources do
  use Mix.Task

  alias Fittrack.Training.ExerciseTemplateImporter

  @shortdoc "Refreshes existing exercise template source metadata and media"

  @moduledoc """
  Refreshes existing exercise templates from WGER without inserting new templates.

  This task is meant to repair normalized source metadata, muscles, equipment,
  aliases, and image media references for templates already present in Fittrack.
  WGER records that do not match an existing template are skipped.

      MIX_ENV=prod mix fittrack.refresh_exercise_sources --limit 1000 --dry-run
      MIX_ENV=prod mix fittrack.refresh_exercise_sources --limit 1000

  ## Options

    * `--limit` - maximum WGER records to fetch. Defaults to 500.
    * `--dry-run` - fetch and match records without writing changes.

  The optional `WGER_API_KEY` environment variable is used when present.
  """

  @impl true
  def run(args) do
    start_application_without_endpoint()

    {opts, _argv, invalid} =
      OptionParser.parse(args,
        switches: [
          dry_run: :boolean,
          limit: :integer
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    limit = Keyword.get(opts, :limit, 500)
    dry_run = Keyword.get(opts, :dry_run, false)

    Mix.shell().info(
      "Refreshing existing exercise templates from WGER" <>
        " (limit=#{limit}, dry_run=#{dry_run})..."
    )

    case ExerciseTemplateImporter.refresh_existing_from_wger(
           limit: limit,
           api_key: System.get_env("WGER_API_KEY"),
           dry_run: dry_run
         ) do
      %{failures: failures} = report ->
        print_report(report)
        print_failures(failures)

      {:error, reason} ->
        Mix.raise("Refresh failed: #{inspect(reason)}")
    end
  end

  defp start_application_without_endpoint do
    Mix.Task.run("app.config")
    Application.load(:fittrack)
    disable_endpoint_server()

    case Application.ensure_all_started(:fittrack) do
      {:ok, _apps} ->
        :ok

      {:error, reason} ->
        Mix.raise("Could not start Fittrack for source refresh: #{inspect(reason)}")
    end
  end

  defp disable_endpoint_server do
    endpoint_config = Application.get_env(:fittrack, FittrackWeb.Endpoint, [])

    Application.put_env(
      :fittrack,
      FittrackWeb.Endpoint,
      endpoint_config
      |> Keyword.put(:server, false)
      |> Keyword.delete(:http)
      |> Keyword.delete(:https),
      persistent: true
    )
  end

  defp print_report(report) do
    Mix.shell().info("""
    Exercise source refresh complete

    Fetched: #{report.fetched}
    Attempted: #{report.attempted}
    Matched existing: #{report.matched}
    Updated: #{report.updated}
    Skipped unmatched: #{report.skipped}
    Failed: #{report.failed}
    """)
  end

  defp print_failures([]), do: :ok

  defp print_failures(failures) do
    Mix.shell().info("Failed records:")

    failures
    |> Enum.take(10)
    |> Enum.each(fn failure ->
      Mix.shell().info(
        "  - source_id=#{inspect(failure.source_id)} name=#{inspect(failure.name)} " <>
          "errors=#{inspect(failure.errors)}"
      )
    end)

    if length(failures) > 10 do
      Mix.shell().info("  ... #{length(failures) - 10} more failure(s) not shown")
    end
  end
end
