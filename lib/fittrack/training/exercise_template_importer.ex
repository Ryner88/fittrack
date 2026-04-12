defmodule Fittrack.Training.ExerciseTemplateImporter do
  @moduledoc """
  Imports exercise templates from external APIs.

  This module provides functionality to fetch exercise data from external APIs,
  normalize it to match our schema, and insert it into the database using changesets.
  """

  import Ecto.Query, only: [from: 2]

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.Normalizer

  @wger_url "https://wger.de/api/v2/exerciseinfo/"
  @wger_english_language_ids MapSet.new([2])
  @line_break_token "__FITTRACK_LINE_BREAK__"
  @paragraph_break_token "__FITTRACK_PARAGRAPH_BREAK__"
  @named_html_entities %{
    "amp" => "&",
    "apos" => "'",
    "gt" => ">",
    "lt" => "<",
    "nbsp" => " ",
    "quot" => "\"",
    "#39" => "'"
  }

  @doc """
  Imports exercise templates from the WGER API.

  ## Options

    * `:limit` - Maximum number of exercises to import (default: 100)
    * `:api_key` - API key for the WGER API (optional for public resources)

  ## Returns

  A map with counts:
  ```
  %{inserted: count, updated: count, failed: count}
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
    name = preferred_translated_field(translations, "name", exercise["name"])

    description =
      translations
      |> preferred_translated_field("description", exercise["description"])
      |> sanitize_notes()

    primary_muscle = get_first_name(exercise["muscles"])
    equipment = get_first_name(exercise["equipment"])

    %{
      source_id: normalize_source_id(exercise["id"]),
      name: name,
      primary_muscle: normalize_muscle_group(primary_muscle),
      equipment: normalize_equipment(equipment),
      notes: description
    }
  end

  def sanitize_notes(nil), do: nil

  def sanitize_notes(value) when is_binary(value) do
    value
    |> replace_block_tags_with_breaks()
    |> strip_html_tags()
    |> decode_html_entities()
    |> normalize_whitespace()
    |> blank_to_nil()
  end

  def sanitize_notes(value), do: value |> to_string() |> sanitize_notes()

  @doc """
  Inserts normalized templates into the database using changesets.

  Returns a map with counts for inserted, updated, and failed operations.
  """
  def insert_templates(templates) do
    {inserted, updated, failed} =
      Enum.reduce(templates, {0, 0, 0}, fn attrs, {ins, upd, fail} ->
        case upsert_template(attrs) do
          {:ok, :inserted, _template} -> {ins + 1, upd, fail}
          {:ok, :updated, _template} -> {ins, upd + 1, fail}
          {:error, _changeset} -> {ins, upd, fail + 1}
        end
      end)

    %{inserted: inserted, updated: updated, failed: failed}
  end

  @doc """
  Inserts or updates a single template based on `source_id`.
  """
  def upsert_template(attrs) do
    case find_existing_template(attrs) do
      nil ->
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, template} -> {:ok, :inserted, template}
          {:error, changeset} -> {:error, changeset}
        end

      %ExerciseTemplate{} = template ->
        template
        |> ExerciseTemplate.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_template} -> {:ok, :updated, updated_template}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  # Private helpers

  defp find_existing_template(%{source_id: source_id} = attrs) when not is_nil(source_id) do
    Repo.get_by(ExerciseTemplate, source_id: source_id) || find_legacy_template_match(attrs)
  end

  defp find_existing_template(_attrs), do: nil

  defp find_legacy_template_match(attrs) do
    normalized_name = Normalizer.normalize_text(attrs.name)
    normalized_equipment = Normalizer.normalize_text(attrs.equipment)

    Repo.one(
      from template in ExerciseTemplate,
        where:
          is_nil(template.source_id) and
            template.normalized_name == ^normalized_name and
            template.normalized_equipment == ^normalized_equipment
    )
  end

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

  defp replace_block_tags_with_breaks(text) do
    text
    |> then(&Regex.replace(~r/<\s*br\s*\/?\s*>/i, &1, @line_break_token))
    |> then(&Regex.replace(~r/<\s*\/\s*p\s*>/i, &1, @paragraph_break_token))
    |> then(&Regex.replace(~r/<\s*p\b[^>]*>/i, &1, ""))
    |> then(&Regex.replace(~r/<\s*\/\s*li\s*>/i, &1, @line_break_token))
    |> then(&Regex.replace(~r/<\s*li\b[^>]*>/i, &1, "- "))
    |> then(&Regex.replace(~r/<\s*\/?\s*(ol|ul|div)\b[^>]*>/i, &1, @line_break_token))
  end

  defp strip_html_tags(text) do
    Regex.replace(~r/<[^>]+>/, text, "")
  end

  defp decode_html_entities(text) do
    Regex.replace(~r/&(#x?[0-9A-Fa-f]+|\w+);/, text, fn _full, entity ->
      decode_html_entity(entity)
    end)
  end

  defp decode_html_entity("#x" <> hex), do: decode_codepoint(hex, 16)
  defp decode_html_entity("#X" <> hex), do: decode_codepoint(hex, 16)
  defp decode_html_entity("#" <> digits), do: decode_codepoint(digits, 10)

  defp decode_html_entity(entity),
    do: Map.get(@named_html_entities, String.downcase(entity), "&#{entity};")

  defp decode_codepoint(raw, base) do
    case Integer.parse(raw, base) do
      {codepoint, ""} when codepoint >= 0 and codepoint <= 0x10FFFF ->
        try do
          <<codepoint::utf8>>
        rescue
          ArgumentError -> "&#{raw};"
        end

      _ ->
        "&#{raw};"
    end
  end

  defp normalize_whitespace(text) do
    normalized_text =
      text
      |> String.replace(@paragraph_break_token, "\n\n")
      |> String.replace(@line_break_token, "\n")
      |> String.replace("\u00A0", " ")
      |> String.replace(~r/\r\n?/, "\n")
      |> String.replace(~r/[ \t\f\v]+/, " ")

    normalized_text
    |> String.split("\n", trim: false)
    |> Enum.map(&String.trim/1)
    |> Enum.join("\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(text), do: text

  defp normalize_source_id(value) when is_integer(value), do: value

  defp normalize_source_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {source_id, ""} -> source_id
      _ -> nil
    end
  end

  defp normalize_source_id(_), do: nil

  defp preferred_translated_field(translations, field, fallback) do
    english_value =
      translations
      |> Enum.find_value(fn translation ->
        if english_translation?(translation), do: present_string(translation[field]), else: nil
      end)

    any_value =
      translations
      |> Enum.find_value(fn translation -> present_string(translation[field]) end)

    english_value || any_value || fallback
  end

  defp english_translation?(translation) when is_map(translation) do
    direct_language_id = translation["language"]

    english_language_id?(direct_language_id) or
      Enum.any?(translation_language_values(translation), &english_language_value?/1)
  end

  defp english_translation?(_), do: false

  defp translation_language_values(translation) do
    direct_values =
      [
        translation["language"],
        translation["lang"],
        translation["language_name"],
        translation["language_short"],
        translation["language_short_name"],
        translation["language_full_name"]
      ]

    nested_values =
      case translation["language"] do
        language when is_map(language) ->
          [
            language["short_name"],
            language["short"],
            language["name"],
            language["full_name"],
            language["abbreviation"]
          ]

        _ ->
          []
      end

    direct_values ++ nested_values
  end

  defp english_language_value?(value) when is_binary(value) do
    normalized = String.trim(value) |> String.downcase()
    normalized in ["en", "eng", "english", "english (us)", "english (uk)"]
  end

  defp english_language_value?(value) when is_integer(value), do: english_language_id?(value)
  defp english_language_value?(_), do: false

  defp english_language_id?(value) when is_integer(value), do: MapSet.member?(@wger_english_language_ids, value)
  defp english_language_id?(_), do: false

  defp present_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: value
  end

  defp present_string(_), do: nil
end
