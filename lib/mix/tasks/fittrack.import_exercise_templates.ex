defmodule Mix.Tasks.Fittrack.ImportExerciseTemplates do
  use Mix.Task

  alias Fittrack.Training.ExerciseTemplateImporter

  @shortdoc "Imports exercise templates from external APIs"

  @moduledoc """
  Imports exercise templates from external APIs.

  Currently supports the WGER API.

  ## Environment Variables

    * `WGER_API_KEY` - Your WGER API key from https://wger.de/user/api-key
      (optional for public resources)

  ## Examples

      mix fittrack.import_exercise_templates
      mix fittrack.import_exercise_templates --limit 50
      mix fittrack.import_exercise_templates --fixture controlled_failures
      WGER_API_KEY=your_key_here mix fittrack.import_exercise_templates
  """

  @impl true
  def run(args) do
    Application.load(:fittrack)

    endpoint_config =
      Application.get_env(:fittrack, FittrackWeb.Endpoint, [])

    Application.put_env(
      :fittrack,
      FittrackWeb.Endpoint,
      Keyword.put(endpoint_config, :server, false),
      persistent: true
    )

    Mix.Task.run("app.start")

    {opts, _argv, invalid} =
      OptionParser.parse(args, switches: [limit: :integer, fixture: :string])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    limit = Keyword.get(opts, :limit, 100)
    api_key = System.get_env("WGER_API_KEY")
    fixture = Keyword.get(opts, :fixture)

    announce_import_source(limit, fixture)

    case import_exercises(limit, api_key, fixture) do
      %{
        fetched: fetched,
        attempted: attempted,
        inserted: inserted,
        updated: updated,
        failed: failed,
        failures: failures
      } ->
        Mix.shell().info("""
        Import completed successfully!

        Results:
          - Fetched: #{fetched}
          - Attempted: #{attempted}
          - Inserted: #{inserted}
          - Updated: #{updated}
          - Failed: #{failed}
        """)

        print_failures(failures)

      {:error, reason} ->
        Mix.raise("Import failed: #{inspect(reason)}")
    end
  end

  defp announce_import_source(limit, nil) do
    Mix.shell().info("Importing up to #{limit} exercises from WGER API...")
  end

  defp announce_import_source(_limit, fixture) do
    Mix.shell().info("Importing exercise templates from fixture #{inspect(fixture)}...")
  end

  defp import_exercises(limit, api_key, nil) do
    ExerciseTemplateImporter.import_from_wger(limit: limit, api_key: api_key)
  end

  defp import_exercises(_limit, _api_key, "controlled_failures") do
    templates = controlled_failure_fixture_templates()

    templates
    |> ExerciseTemplateImporter.insert_templates()
    |> Map.put(:fetched, length(templates))
    |> Map.put(:attempted, length(templates))
  end

  defp import_exercises(_limit, _api_key, fixture) do
    {:error, "Unknown fixture #{inspect(fixture)}"}
  end

  defp controlled_failure_fixture_templates do
    for index <- 1..12 do
      %{
        source_id: nil,
        name: nil,
        primary_muscle: "Fixture Muscle #{index}",
        equipment: "Fixture Equipment #{index}",
        notes: "Deterministic CLI failure fixture #{index}"
      }
    end
  end

  defp print_failures([]), do: :ok

  defp print_failures(failures) do
    Mix.shell().info("Failed records:")

    failures
    |> Enum.take(10)
    |> Enum.each(fn failure ->
      Mix.shell().info("""
        - source_id=#{inspect(failure.source_id)} name=#{inspect(failure.name)} errors=#{inspect(failure.errors)}
      """)
    end)

    if length(failures) > 10 do
      Mix.shell().info("  ... #{length(failures) - 10} more failure(s) not shown")
    end
  end
end
