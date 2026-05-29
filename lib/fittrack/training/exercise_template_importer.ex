defmodule Fittrack.Training.ExerciseTemplateImporter do
  @moduledoc """
  Imports exercise templates from external APIs.

  This module provides functionality to fetch exercise data from external APIs,
  normalize it to match our schema, and insert it into the database using changesets.
  """

  import Ecto.Query, only: [from: 2]

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseAlias
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource
  alias Fittrack.Training.Normalizer
  alias Fittrack.Training.Slug

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
    api_key = Keyword.get(opts, :api_key)
    http_client = Keyword.get(opts, :http_client, Req)

    with {:ok, exercises} <- fetch_exercises_from_wger(api_key, limit, http_client),
         normalized <- normalize_exercises_from_wger(exercises) do
      normalized
      |> insert_templates()
      |> Map.put(:fetched, length(exercises))
      |> Map.put(:attempted, length(normalized))
    end
  end

  @doc """
  Fetches exercises from the WGER API.
  """
  def fetch_exercises_from_wger(api_key, limit, http_client \\ Req)

  def fetch_exercises_from_wger(_api_key, limit, _http_client) when limit <= 0, do: {:ok, []}

  def fetch_exercises_from_wger(api_key, limit, http_client) do
    headers = if api_key, do: [{"Authorization", "Token #{api_key}"}], else: []

    fetch_wger_page(@wger_url, headers, limit, [], http_client)
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

    muscles =
      exercise["muscles"] |> List.wrap() |> Enum.map(&extract_name/1) |> Enum.reject(&is_nil/1)

    equipment =
      exercise["equipment"] |> List.wrap() |> Enum.map(&extract_name/1) |> Enum.reject(&is_nil/1)

    primary_muscle = List.first(muscles)
    primary_equipment = List.first(equipment)

    %{
      source_id: normalize_source_id(exercise["id"]),
      name: name,
      slug: Slug.slugify(name),
      canonical_slug: Slug.slugify(canonical_name(name, primary_equipment)),
      primary_muscle: normalize_muscle_group(primary_muscle),
      secondary_muscles: muscles |> Enum.drop(1) |> Enum.map(&normalize_muscle_group/1),
      equipment: normalize_equipment(primary_equipment),
      equipment_names: Enum.map(equipment, &normalize_equipment/1),
      weighted_tags: weighted_tags(name, muscles, equipment),
      is_verified: false,
      is_ai_generated: false,
      is_deprecated: false,
      quality_score: quality_score(name, primary_muscle, primary_equipment, description),
      is_compound: length(muscles) > 1,
      image_url: image_url_from_wger(exercise),
      media_items: media_items_from_wger(exercise),
      source_payload: exercise,
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
    {inserted, updated, failed, failures} =
      Enum.reduce(templates, {0, 0, 0, []}, fn attrs, {ins, upd, fail, failures} ->
        case upsert_template(attrs) do
          {:ok, :inserted, _template} ->
            {ins + 1, upd, fail, failures}

          {:ok, :updated, _template} ->
            {ins, upd + 1, fail, failures}

          {:error, changeset} ->
            failure = %{
              source_id: Map.get(attrs, :source_id),
              name: Map.get(attrs, :name),
              errors: changeset_errors(changeset)
            }

            {ins, upd, fail + 1, [failure | failures]}
        end
      end)

    %{
      inserted: inserted,
      updated: updated,
      failed: failed,
      failures: Enum.reverse(failures)
    }
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
          {:ok, template} ->
            persist_normalized_catalog(template, attrs)
            {:ok, :inserted, template}

          {:error, changeset} ->
            {:error, changeset}
        end

      %ExerciseTemplate{} = template ->
        template
        |> ExerciseTemplate.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_template} ->
            persist_normalized_catalog(updated_template, attrs)
            {:ok, :updated, updated_template}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, :ambiguous_legacy_match} ->
        {:error, ambiguous_legacy_match_changeset(attrs)}

      {:error, :unsafe_legacy_match} ->
        {:error, ambiguous_legacy_match_changeset(attrs)}
    end
  end

  # Private helpers

  defp persist_normalized_catalog(%ExerciseTemplate{} = template, attrs) do
    persist_template_source(template, attrs)
    persist_template_aliases(template, attrs)
    persist_template_muscles(template, attrs)
    persist_template_equipment(template, attrs)
    persist_template_media(template, attrs)
  end

  defp persist_template_aliases(template, attrs) do
    attrs
    |> alias_names()
    |> Enum.with_index()
    |> Enum.each(fn {name, position} ->
      normalized_name = Normalizer.normalize_text(name)

      exercise_alias =
        Repo.get_by(ExerciseAlias,
          exercise_template_id: template.id,
          normalized_name: normalized_name
        ) || %ExerciseAlias{}

      exercise_alias
      |> ExerciseAlias.changeset(%{
        exercise_template_id: template.id,
        name: name,
        kind: if(position == 0, do: "canonical", else: "alias"),
        source: "wger",
        weight: max(10 - position, 1)
      })
      |> Repo.insert_or_update()
    end)
  end

  defp alias_names(attrs) do
    [
      Map.get(attrs, :name),
      canonical_name(Map.get(attrs, :name), Map.get(attrs, :equipment))
    ]
    |> Enum.concat(generated_aliases(Map.get(attrs, :name), Map.get(attrs, :equipment)))
    |> Enum.reject(&blank?/1)
    |> Enum.uniq_by(&Normalizer.normalize_text/1)
  end

  defp generated_aliases(name, equipment) do
    normalized_equipment = Normalizer.normalize_text(equipment)

    cond do
      blank?(name) ->
        []

      normalized_equipment == "barbell" ->
        ["Barbell #{name}", "BB #{name}"]

      normalized_equipment == "dumbbell" ->
        ["Dumbbell #{name}", "DB #{name}"]

      true ->
        []
    end
  end

  defp persist_template_source(_template, attrs) when not is_map(attrs), do: :ok

  defp persist_template_source(template, attrs) do
    with source_id when not is_nil(source_id) <- Map.get(attrs, :source_id) do
      external_id = to_string(source_id)

      template_source =
        Repo.get_by(ExerciseTemplateSource, source: "wger", external_id: external_id) ||
          %ExerciseTemplateSource{}

      template_source
      |> ExerciseTemplateSource.changeset(%{
        exercise_template_id: template.id,
        source: "wger",
        external_id: external_id,
        source_url: "#{@wger_url}#{external_id}/",
        payload: Map.get(attrs, :source_payload, %{}),
        imported_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.insert_or_update()
    end

    :ok
  end

  defp persist_template_muscles(template, attrs) do
    muscles =
      [
        {"primary", 0, Map.get(attrs, :primary_muscle)}
        | attrs
          |> Map.get(:secondary_muscles, [])
          |> List.wrap()
          |> Enum.with_index(1)
          |> Enum.map(fn {muscle, position} -> {"secondary", position, muscle} end)
      ]
      |> Enum.reject(fn {_role, _position, name} -> blank?(name) end)
      |> Enum.uniq_by(fn {role, _position, name} -> {role, Normalizer.normalize_text(name)} end)

    Repo.delete_all(
      from template_muscle in ExerciseTemplateMuscle,
        where: template_muscle.exercise_template_id == ^template.id
    )

    Enum.each(muscles, fn {role, position, name} ->
      muscle = upsert_muscle(name)

      %ExerciseTemplateMuscle{}
      |> ExerciseTemplateMuscle.changeset(%{
        exercise_template_id: template.id,
        exercise_muscle_id: muscle.id,
        role: role,
        position: position
      })
      |> Repo.insert()
    end)
  end

  defp persist_template_equipment(template, attrs) do
    equipment_names =
      attrs
      |> Map.get(:equipment_names, [Map.get(attrs, :equipment)])
      |> List.wrap()
      |> Enum.reject(&blank?/1)
      |> Enum.uniq_by(&Normalizer.normalize_text/1)

    Repo.delete_all(
      from template_equipment in ExerciseTemplateEquipment,
        where: template_equipment.exercise_template_id == ^template.id
    )

    equipment_names
    |> Enum.with_index()
    |> Enum.each(fn {name, position} ->
      equipment = upsert_equipment(name)

      %ExerciseTemplateEquipment{}
      |> ExerciseTemplateEquipment.changeset(%{
        exercise_template_id: template.id,
        exercise_equipment_id: equipment.id,
        position: position
      })
      |> Repo.insert()
    end)
  end

  defp persist_template_media(template, attrs) do
    attrs
    |> Map.get(:media_items, media_items_from_image_url(Map.get(attrs, :image_url)))
    |> List.wrap()
    |> Enum.reject(fn media -> blank?(Map.get(media, :source_url)) end)
    |> Enum.each(fn media_attrs ->
      source_url = Map.get(media_attrs, :source_url)

      media =
        Repo.get_by(ExerciseMedia, source_url: source_url) ||
          %ExerciseMedia{}

      media
      |> ExerciseMedia.changeset(Map.put(media_attrs, :exercise_template_id, template.id))
      |> Repo.insert_or_update()
    end)
  end

  defp upsert_muscle(name) do
    normalized_name = Normalizer.normalize_text(name)

    Repo.get_by(ExerciseMuscle, normalized_name: normalized_name) ||
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{name: name, region: muscle_region(name)})
      |> Repo.insert!()
  end

  defp upsert_equipment(name) do
    normalized_name = Normalizer.normalize_text(name)

    Repo.get_by(ExerciseEquipment, normalized_name: normalized_name) ||
      %ExerciseEquipment{}
      |> ExerciseEquipment.changeset(%{name: name, category: equipment_category(name)})
      |> Repo.insert!()
  end

  defp muscle_region(name) do
    case Normalizer.normalize_text(name) do
      normalized
      when normalized in ["chest", "back", "shoulders", "biceps", "triceps", "traps"] ->
        "upper_body"

      normalized when normalized in ["quads", "quadriceps", "hamstrings", "glutes", "calves"] ->
        "lower_body"

      normalized when normalized in ["abs", "core", "abdominals", "rectus abdominis"] ->
        "core"

      _ ->
        nil
    end
  end

  defp equipment_category(name) do
    case Normalizer.normalize_text(name) do
      "bodyweight" -> "bodyweight"
      normalized when normalized in ["barbell", "dumbbell", "kettlebell"] -> "free_weight"
      normalized when normalized in ["machine", "cable"] -> "machine"
      "band" -> "accessory"
      _ -> nil
    end
  end

  defp canonical_name(name, equipment) do
    normalized_name = Normalizer.normalize_text(name)
    normalized_equipment = Normalizer.normalize_text(equipment)

    cond do
      blank?(name) ->
        nil

      normalized_equipment in ["", normalized_name] ->
        name

      String.contains?(normalized_name, normalized_equipment) ->
        name

      normalized_equipment == "bodyweight" ->
        name

      true ->
        "#{equipment} #{name}"
    end
  end

  defp weighted_tags(name, muscles, equipment) do
    [name | List.wrap(muscles) ++ List.wrap(equipment)]
    |> Enum.reject(&blank?/1)
    |> Enum.flat_map(fn value ->
      normalized = Normalizer.normalize_text(value)
      [normalized, Slug.slugify(value)]
    end)
    |> Enum.reject(&blank?/1)
    |> Enum.uniq()
  end

  defp quality_score(name, primary_muscle, equipment, notes) do
    [
      {name, 25},
      {primary_muscle, 25},
      {equipment, 15},
      {notes, 20}
    ]
    |> Enum.reduce(0, fn {value, score}, acc ->
      if blank?(value), do: acc, else: acc + score
    end)
  end

  defp find_existing_template(%{source_id: source_id} = attrs) when not is_nil(source_id) do
    Repo.get_by(ExerciseTemplate, source_id: source_id) || find_legacy_template_match(attrs)
  end

  defp find_existing_template(_attrs), do: nil

  defp find_legacy_template_match(attrs) do
    normalized_name = Normalizer.normalize_text(attrs.name)
    normalized_equipment = Normalizer.normalize_text(attrs.equipment)
    normalized_primary_muscle = normalize_legacy_value(attrs.primary_muscle)

    matches =
      Repo.all(
        from template in ExerciseTemplate,
          where:
            is_nil(template.source_id) and
              template.normalized_name == ^normalized_name and
              template.normalized_equipment == ^normalized_equipment
      )

    case Enum.filter(matches, &legacy_template_safe_to_adopt?(&1, normalized_primary_muscle)) do
      [template] -> template
      [] when matches == [] -> nil
      [] -> {:error, :unsafe_legacy_match}
      _templates -> {:error, :ambiguous_legacy_match}
    end
  end

  defp legacy_template_safe_to_adopt?(template, normalized_primary_muscle) do
    normalize_legacy_value(template.primary_muscle) == normalized_primary_muscle
  end

  defp normalize_legacy_value(nil), do: nil

  defp normalize_legacy_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> String.downcase(trimmed)
    end
  end

  defp ambiguous_legacy_match_changeset(attrs) do
    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(attrs)
    |> Ecto.Changeset.add_error(
      :source_id,
      "cannot safely adopt an existing legacy template for this source; resolve the legacy template manually"
    )
  end

  defp fetch_wger_page(_url, _headers, 0, acc, _http_client), do: {:ok, acc}

  defp fetch_wger_page(url, headers, remaining, acc, http_client) do
    case http_client.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, results, next_url} <- extract_wger_page(body) do
          page_items = Enum.take(results, remaining)
          updated_acc = acc ++ page_items
          next_remaining = remaining - length(page_items)

          cond do
            next_remaining <= 0 ->
              {:ok, updated_acc}

            is_binary(next_url) and next_url != "" and length(page_items) == length(results) ->
              fetch_wger_page(next_url, headers, next_remaining, updated_acc, http_client)

            true ->
              {:ok, updated_acc}
          end
        end

      {:ok, %{status: status}} ->
        {:error, "API request failed with status #{status}"}

      {:error, error} ->
        {:error, "Request failed: #{inspect(error)}"}
    end
  end

  defp extract_wger_page(%{"results" => results} = body) when is_list(results) do
    {:ok, results, body["next"]}
  end

  defp extract_wger_page(body) do
    {:error, "Unexpected WGER response shape: #{inspect(body)}"}
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

  defp extract_name(%{"name_en" => name_en, "name" => name}) do
    present_string(name_en) || present_string(name)
  end

  defp extract_name(%{"name_en" => name_en}), do: present_string(name_en)
  defp extract_name(%{"name" => name}), do: present_string(name)
  defp extract_name(value) when is_binary(value), do: present_string(value)
  defp extract_name(_), do: nil

  defp image_url_from_wger(exercise) do
    exercise
    |> Map.get("images", [])
    |> List.wrap()
    |> Enum.sort_by(&image_sort_rank/1)
    |> Enum.find_value(&extract_image_url/1)
  end

  defp image_sort_rank(%{"is_main" => true}), do: 0
  defp image_sort_rank(%{"main" => true}), do: 0
  defp image_sort_rank(_image), do: 1

  defp extract_image_url(%{"image" => image_url}), do: valid_image_url(image_url)
  defp extract_image_url(%{"url" => image_url}), do: valid_image_url(image_url)
  defp extract_image_url(image_url) when is_binary(image_url), do: valid_image_url(image_url)
  defp extract_image_url(_image), do: nil

  defp media_items_from_wger(exercise) do
    exercise
    |> Map.get("images", [])
    |> List.wrap()
    |> Enum.sort_by(&image_sort_rank/1)
    |> Enum.with_index()
    |> Enum.flat_map(fn {image, position} ->
      case extract_image_url(image) do
        nil ->
          []

        source_url ->
          [
            %{
              kind: "image",
              source: "wger",
              source_id: image_source_id(image),
              source_url: source_url,
              provider_attribution: provider_attribution(image),
              cache_status: "remote_only",
              is_primary: position == 0,
              metadata: image_metadata(image)
            }
          ]
      end
    end)
  end

  defp media_items_from_image_url(nil), do: []

  defp media_items_from_image_url(source_url) do
    [%{kind: "image", source_url: source_url, is_primary: true}]
  end

  defp image_source_id(%{"id" => id}) when not is_nil(id), do: to_string(id)
  defp image_source_id(_image), do: nil

  defp image_metadata(image) when is_map(image) do
    image
    |> Map.take(["license", "license_author", "author", "uuid"])
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new()
  end

  defp image_metadata(_image), do: %{}

  defp provider_attribution(%{"license_author" => author}) when is_binary(author),
    do: present_string(author)

  defp provider_attribution(%{"author" => author}) when is_binary(author),
    do: present_string(author)

  defp provider_attribution(_image), do: nil

  defp valid_image_url(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "http://" <> _ = url -> url
      "https://" <> _ = url -> url
      _ -> nil
    end
  end

  defp valid_image_url(_value), do: nil

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)

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

  defp changeset_errors(changeset) do
    Enum.into(changeset.errors, %{}, fn {field, {message, opts}} ->
      rendered =
        Enum.reduce(opts, message, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)

      {field, rendered}
    end)
  end

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

  defp english_language_id?(value) when is_integer(value),
    do: MapSet.member?(@wger_english_language_ids, value)

  defp english_language_id?(_), do: false

  defp present_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: value
  end

  defp present_string(_), do: nil
end
