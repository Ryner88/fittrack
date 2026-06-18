defmodule Mix.Tasks.Fittrack.BackfillExerciseMedia do
  use Mix.Task

  alias Fittrack.Training.ExerciseMediaBackfill

  @shortdoc "Backfills and caches WGER exercise media"

  @moduledoc """
  Backfills WGER exercise media into app-owned storage.

      MIX_ENV=prod mix fittrack.backfill_exercise_media --dry-run
      MIX_ENV=prod mix fittrack.backfill_exercise_media --batch-size 50 --max-batches 10
      MIX_ENV=prod mix fittrack.backfill_exercise_media --batch-size 50 --limit 500
      MIX_ENV=prod mix fittrack.backfill_exercise_media --exercise-id 123
      MIX_ENV=prod mix fittrack.backfill_exercise_media --force-check
      MIX_ENV=prod mix fittrack.backfill_exercise_media --sync-remote --limit 100
  """

  @impl true
  def run(args), do: run(args, ExerciseMediaBackfill)

  def run(args, backfill_module) do
    Application.load(:fittrack)
    disable_endpoint_server()
    Mix.Task.run("app.start")

    {opts, _argv, invalid} =
      OptionParser.parse(args,
        switches: [
          dry_run: :boolean,
          limit: :integer,
          batch_size: :integer,
          max_batches: :integer,
          exercise_id: :integer,
          force_check: :boolean,
          skip_download: :boolean,
          sync_remote: :boolean,
          media_type: :string,
          concurrency: :integer
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    opts =
      opts
      |> Keyword.put_new(:api_key, System.get_env("WGER_API_KEY"))
      |> Keyword.put_new(:media_type, "all")

    case backfill_module.run(opts) do
      {:ok, report} -> print_report(report)
      {:error, reason} -> Mix.raise("Exercise media backfill failed: #{inspect(reason)}")
    end
  end

  defp disable_endpoint_server do
    endpoint_config = Application.get_env(:fittrack, FittrackWeb.Endpoint, [])

    Application.put_env(
      :fittrack,
      FittrackWeb.Endpoint,
      Keyword.put(endpoint_config, :server, false),
      persistent: true
    )
  end

  def print_report(report) do
    Mix.shell().info("""
    Exercise media backfill complete

    Batches: #{Map.get(report, :batches, 0)}
    Fetched: #{report.fetched}
    Cached: #{report.cached}
    Already cached: #{Map.get(report, :already_cached, 0)}
    Missing: #{report.missing}
    Skipped: #{report.skipped}
    Unsupported: #{Map.get(report, :unsupported, 0)}
    Stale: #{report.stale}
    Failed: #{report.failed}
    Exercises with no media: #{report.exercises_with_no_media}
    """)
  end
end
