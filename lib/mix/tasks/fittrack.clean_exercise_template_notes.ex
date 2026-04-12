defmodule Mix.Tasks.Fittrack.CleanExerciseTemplateNotes do
  use Mix.Task

  import Ecto.Query, only: [from: 2]

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateImporter

  @shortdoc "Sanitizes existing exercise template notes into plain text"

  @moduledoc """
  Sanitizes `exercise_templates.notes` in place by stripping HTML and decoding HTML entities.

  This is intended for repairing existing imported WGER descriptions after the importer
  logic changes.

  ## Examples

      mix fittrack.clean_exercise_template_notes
      mix fittrack.clean_exercise_template_notes --dry-run
  """

  @impl true
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run? = Keyword.get(opts, :dry_run, false)

    Mix.Task.run("app.start")

    templates =
      Repo.all(
        from template in ExerciseTemplate,
          where: not is_nil(template.notes) and template.notes != ""
      )

    {updated, unchanged, failed} =
      Enum.reduce(templates, {0, 0, 0}, fn template, {updated, unchanged, failed} ->
        cleaned_notes = ExerciseTemplateImporter.sanitize_notes(template.notes)

        cond do
          cleaned_notes == template.notes ->
            {updated, unchanged + 1, failed}

          dry_run? ->
            {updated + 1, unchanged, failed}

          true ->
            case template
                 |> ExerciseTemplate.changeset(%{notes: cleaned_notes})
                 |> Repo.update() do
              {:ok, _template} -> {updated + 1, unchanged, failed}
              {:error, _changeset} -> {updated, unchanged, failed + 1}
            end
        end
      end)

    Mix.shell().info("""
    Exercise template note cleanup complete!

    Results:
      - Updated: #{updated}
      - Unchanged: #{unchanged}
      - Failed: #{failed}
      - Dry run: #{dry_run?}
    """)
  end
end
