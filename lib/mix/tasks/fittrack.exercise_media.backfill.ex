defmodule Mix.Tasks.Fittrack.ExerciseMedia.Backfill do
  use Mix.Task

  @shortdoc "Backfills and caches exercise media in bounded batches"

  @moduledoc """
  Alias for `mix fittrack.backfill_exercise_media`.

      MIX_ENV=prod mix fittrack.exercise_media.backfill --batch-size 50 --max-batches 10
      MIX_ENV=prod mix fittrack.exercise_media.backfill --batch-size 50 --limit 500
      MIX_ENV=prod mix fittrack.exercise_media.backfill --dry-run
  """

  @impl true
  def run(args) do
    Mix.Tasks.Fittrack.BackfillExerciseMedia.run(args)
  end
end
