defmodule Mix.Tasks.PopulateExerciseImages do
  @moduledoc "Populate exercise_url with placeholder images for demo purposes"
  use Mix.Task

  import Ecto.Query
  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate

  @shortdoc "Add placeholder images to exercises"
  @placeholder_colors [
    "FF6B6B",
    "4ECDC4",
    "45B7D1",
    "96CEB4",
    "FFEAA7",
    "DDA15E",
    "BC6C25",
    "A2D5C6",
    "D6CDA4",
    "FF8C42"
  ]

  def run(_args) do
    # Only start necessary apps, skip web endpoints
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:fittrack)

    IO.puts("Populating exercise images with placeholders...")

    count =
      ExerciseTemplate
      |> where([e], is_nil(e.image_url))
      |> Repo.all()
      |> Enum.with_index()
      |> Enum.reduce(0, fn {template, idx}, acc ->
        color = Enum.at(@placeholder_colors, rem(idx, Enum.count(@placeholder_colors)))
        # Using placehold.co which is simple and reliable
        placeholder_url = "https://placehold.co/400x300/#{color}/FFFFFF?text=#{rem(idx, 100)}"

        template
        |> ExerciseTemplate.changeset(%{image_url: placeholder_url})
        |> Repo.update!()

        if rem(idx + 1, 50) == 0 do
          IO.puts("  Updated #{idx + 1} exercises...")
        end

        acc + 1
      end)

    IO.puts("✓ Successfully updated #{count} exercises with placeholder images")
  end
end
