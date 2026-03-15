defmodule Fittrack.Training.ExerciseTemplateImporter do
  @moduledoc """
  Imports exercise templates from external APIs.

  This module provides functionality to fetch exercise data from external APIs,
  normalize it to match our schema, and insert it into the database using changesets.
  """

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate

  @wger_url "https://wger.de/api/v2/exerciseinfo/"

  @doc """
  Imports exercise templates from the WGER API.

  ## Options

    * `:limit` - Maximum number of exercises to import (default: 100)
    * `:api_key` - API key for the WGER API (optional for public resources)

  ## Returns

  A map with counts:
  ```
  %{inserted: count, skipped: count, failed: count}
  ```
  """
  def import_from_wger(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    api_key = Keyword.get(opts, :api_key) || raise "API key required"

    with {:ok, exercises} <- fetch_exercises_from_wger(api_key, limit),
         normalized <- normalize_exercises_from_wger(exercises) do
      insert_templates(normalized)
    end
  end

  @doc """
  Fetches exercises from the WGER API.
  """
  def fetch_exercises_from_wger(api_key, limit) do
    url = @wger_url

    headers = if api_key, do: [{"Authorization", "Token #{api_key}"}], else: []

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        exercises = Enum.take(body["results"], limit)
        {:ok, exercises}

      {:ok, %{status: status}} ->
        {:error, "API request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  @doc """
  Normalizes WGER API response data to match our schema.

  Expected API response format:
  ```
  %{
    "name" => "Push-up",
    "description" => "Description...",
    "muscles" => [%{"name" => "Pectorals"}],
    "equipment" => [%{"name" => "body weight"}]
  }
  ```
  """
  def normalize_exercises_from_wger(exercises) when is_list(exercises) do
    Enum.map(exercises, &normalize_exercise_from_wger/1)
  end

  def normalize_exercise_from_wger(exercise) do
    translations = exercise["translations"] || []
    first_translation = List.first(translations) || %{}
    name = first_translation["name"] || exercise["name"]
    description = first_translation["description"] || exercise["description"]

    primary_muscle = get_first_name(exercise["muscles"])
    equipment = get_first_name(exercise["equipment"])

    %{
      name: name,
      primary_muscle: normalize_muscle_group(primary_muscle),
      equipment: normalize_equipment(equipment),
      notes: description
    }
  end

  @doc """
  Inserts normalized templates into the database using changesets.

  Returns a map with counts for inserted, skipped, and failed operations.
  """
  def insert_templates(templates) do
    {inserted, skipped, failed} =
      Enum.reduce(templates, {0, 0, 0}, fn attrs, {ins, skip, fail} ->
        case insert_template(attrs) do
          {:ok, _template} -> {ins + 1, skip, fail}
          {:error, :already_exists} -> {ins, skip + 1, fail}
          {:error, _changeset} -> {ins, skip, fail + 1}
        end
      end)

    %{inserted: inserted, skipped: skipped, failed: failed}
  end

  @doc """
  Inserts a single template, handling unique constraint violations.
  """
  def insert_template(attrs) do
    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, template} ->
        {:ok, template}

      {:error, changeset} ->
        if unique_constraint_violation?(changeset) do
          {:error, :already_exists}
        else
          {:error, changeset}
        end
    end
  end

  # Private helpers

  defp normalize_muscle_group(nil), do: nil

  defp normalize_muscle_group(target) do
    # Map common API muscle group names to our schema
    case String.downcase(target) do
      "pectorals" -> "Chest"
      "biceps" -> "Biceps"
      "triceps" -> "Triceps"
      "quadriceps" -> "Quads"
      "hamstrings" -> "Hamstrings"
      "glutes" -> "Glutes"
      "calves" -> "Calves"
      "shoulders" -> "Shoulders"
      "abdominals" -> "Abs"
      "lats" -> "Back"
      "traps" -> "Traps"
      "rhomboids" -> "Back"
      "delts" -> "Shoulders"
      other -> String.capitalize(other)
    end
  end

  defp normalize_equipment(nil), do: nil

  defp normalize_equipment(equipment) do
    # Map common API equipment names to our schema
    case String.downcase(equipment) do
      "body weight" -> "Bodyweight"
      "dumbbell" -> "Dumbbell"
      "barbell" -> "Barbell"
      "cable" -> "Cable"
      "machine" -> "Machine"
      "kettlebell" -> "Kettlebell"
      "resistance band" -> "Band"
      other -> String.capitalize(other)
    end
  end

  defp get_first_name(nil), do: nil
  defp get_first_name([]), do: nil
  defp get_first_name([%{"name" => name} | _]), do: name
  defp get_first_name(_), do: nil

  defp unique_constraint_violation?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {message, _opts}} ->
      String.contains?(message, "has already been taken")
    end)
  end
end
