defmodule Mix.Tasks.Fittrack.BackfillExerciseTaxonomy do
  use Mix.Task

  alias Fittrack.Training.ExerciseTaxonomyBackfill

  @shortdoc "Backfills normalized exercise taxonomy and source metadata"

  @moduledoc """
  Backfills normalized muscle, equipment, and source metadata for existing shared
  exercise templates without deleting templates or cached media.

      MIX_ENV=prod mix fittrack.backfill_exercise_taxonomy --dry-run
      MIX_ENV=prod mix fittrack.backfill_exercise_taxonomy
      MIX_ENV=prod mix fittrack.backfill_exercise_taxonomy --template-id 123

  ## Options

    * `--dry-run` - report changes without writing them.
    * `--limit` - maximum number of templates to inspect.
    * `--template-id` - inspect and repair one template.
  """

  @impl true
  def run(args), do: run(args, ExerciseTaxonomyBackfill)

  def run(args, backfill_module) do
    start_application_without_endpoint()

    {opts, _argv, invalid} =
      OptionParser.parse(args,
        switches: [
          dry_run: :boolean,
          limit: :integer,
          template_id: :integer
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    case backfill_module.run(opts) do
      {:ok, report} ->
        print_report(report)
        print_failures(Map.get(report, :failures, []))

      {:error, reason} ->
        Mix.raise("Exercise taxonomy backfill failed: #{inspect(reason)}")
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
        Mix.raise("Could not start Fittrack for taxonomy backfill: #{inspect(reason)}")
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

  def print_report(report) do
    Mix.shell().info("""
    Exercise taxonomy/source backfill complete

    Total templates inspected: #{report.total_templates_inspected}
    Templates updated: #{report.templates_updated}
    Muscles created: #{report.muscles_created}
    Muscle joins created: #{report.muscle_joins_created}
    Equipment created: #{report.equipment_created}
    Equipment joins created: #{report.equipment_joins_created}
    Sources created: #{report.sources_created}
    Source links updated: #{report.source_links_updated}
    Media cached: #{report.media_cached}
    Media missing: #{report.media_missing}
    Media stale: #{report.media_stale}
    Media failed: #{report.media_failed}
    Skipped records: #{report.skipped_records}
    Errors/failures: #{report.errors}
    """)
  end

  defp print_failures([]), do: :ok

  defp print_failures(failures) do
    Mix.shell().info("Failed records:")

    failures
    |> Enum.take(10)
    |> Enum.each(fn failure ->
      Mix.shell().info(
        "  - template_id=#{inspect(failure.template_id)} error=#{inspect(failure.error)}"
      )
    end)

    if length(failures) > 10 do
      Mix.shell().info("  ... #{length(failures) - 10} more failure(s) not shown")
    end
  end
end
