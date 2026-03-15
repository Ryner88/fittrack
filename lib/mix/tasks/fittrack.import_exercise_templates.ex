defmodule Mix.Tasks.Fittrack.ImportExerciseTemplates do
  use Mix.Task

  alias Fittrack.Training.ExerciseTemplateImporter

  @shortdoc "Imports exercise templates from external APIs"

  @moduledoc """
  Imports exercise templates from external APIs.

  Currently supports the WGER API.

  ## Environment Variables

    * `WGER_API_KEY` - Your WGER API key from https://wger.de/user/api-key (optional for public resources)

  ## Examples

      # Import up to 100 exercises (default)
      mix fittrack.import_exercise_templates

      # Import up to 50 exercises
      mix fittrack.import_exercise_templates --limit 50

      # Use a specific API key
      WGER_API_KEY=your_key_here mix fittrack.import_exercise_templates
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} = OptionParser.parse!(args, switches: [limit: :integer])

    limit = Keyword.get(opts, :limit, 100)
    api_key = System.get_env("WGER_API_KEY")

    Mix.shell().info("Importing up to #{limit} exercises from WGER API...")

    case ExerciseTemplateImporter.import_from_wger(limit: limit, api_key: api_key) do
      %{inserted: inserted, skipped: skipped, failed: failed} ->
        Mix.shell().info("""
        Import completed successfully!

        Results:
          - Inserted: #{inserted}
          - Skipped (already exist): #{skipped}
          - Failed: #{failed}
        """)

      {:error, reason} ->
        Mix.raise("Import failed: #{reason}")
    end
  end
end
