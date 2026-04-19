defmodule Fittrack.Nutrition.ScreenshotImportParser do
  @moduledoc """
  Parses uploaded or pasted nutrition screenshots into normalized food attrs.
  """

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.OpenAIImageParserClient

  def configured? do
    client = parser_client()

    if function_exported?(client, :configured?, 0) do
      client.configured?()
    else
      true
    end
  end

  def parse_image_data(data_url, source_image_metadata \\ %{})

  def parse_image_data(data_url, source_image_metadata) when is_binary(data_url) do
    with true <- String.starts_with?(data_url, "data:image/") || {:error, :invalid_image},
         {:ok, attrs} <- parser_client().parse_image_data(data_url),
         {:ok, attrs} <- normalize_parser_response(attrs, data_url, source_image_metadata) do
      {:ok, Nutrition.barcode_food_defaults(attrs)}
    end
  end

  def parse_image_data(_, _), do: {:error, :invalid_image}

  defp parser_client do
    Application.get_env(:fittrack, :screenshot_import_parser_client, OpenAIImageParserClient)
  end

  defp normalize_parser_response(attrs, data_url, source_image_metadata) when is_map(attrs) do
    attrs = stringify_keys(attrs)
    source_image_metadata = build_source_image_metadata(data_url, source_image_metadata)
    extraction = normalize_extraction(attrs)

    {:ok,
     %{
       "name" => attrs["name"] || extraction["item_name"] || "Imported screenshot item",
       "unit" => attrs["unit"] || "serving",
       "unit_amount" => attrs["unit_amount"] || "1",
       "quantity" => attrs["quantity"] || attrs["unit_amount"] || "1",
       "calories_per_unit" => attrs["calories_per_unit"] || 0,
       "protein_per_unit" => attrs["protein_per_unit"] || 0,
       "carbs_per_unit" => attrs["carbs_per_unit"] || 0,
       "fats_per_unit" => attrs["fats_per_unit"] || 0,
       "fiber_per_unit" => attrs["fiber_per_unit"] || 0,
       "sugar_per_unit" => attrs["sugar_per_unit"] || 0,
       "sodium_mg_per_unit" => attrs["sodium_mg_per_unit"] || 0,
       "micronutrients" => Nutrition.parse_micronutrients(attrs["micronutrients"]),
       "source_image_metadata" => source_image_metadata,
       "parsed_values" => %{
         "detected_context" => extraction["detected_context"],
         "field_mapping" => extraction["field_mapping"],
         "extracted_text" => extraction["extracted_text"],
         "serving_size_text" => extraction["serving_size_text"],
         "venue_name" => extraction["venue_name"],
         "raw_response" => attrs
       }
     }}
  end

  defp normalize_parser_response(_, _, _), do: {:error, :parse_failed}

  defp normalize_extraction(attrs) do
    extraction = stringify_keys(attrs["extraction"] || %{})

    extracted_text =
      case extraction["extracted_text"] || attrs["extracted_text"] do
        text when is_binary(text) ->
          text
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)

        text when is_list(text) ->
          Enum.map(text, &to_string/1)

        _ ->
          []
      end

    field_mapping =
      extraction["field_mapping"]
      |> default_field_mapping(attrs)
      |> stringify_keys()

    detected_context =
      stringify_keys(extraction["detected_context"] || %{})
      |> Map.put_new("kind", detect_context_kind(extraction, extracted_text))

    %{
      "item_name" => extraction["item_name"] || attrs["name"],
      "venue_name" => extraction["venue_name"] || detected_context["venue_name"],
      "serving_size_text" => extraction["serving_size_text"] || attrs["serving_size_text"],
      "field_mapping" => field_mapping,
      "detected_context" => detected_context,
      "extracted_text" => extracted_text
    }
  end

  defp default_field_mapping(nil, attrs), do: default_field_mapping(%{}, attrs)

  defp default_field_mapping(field_mapping, attrs) when map_size(field_mapping) == 0 do
    %{}
    |> maybe_put_field_mapping("name", attrs["name"])
    |> maybe_put_field_mapping("unit_amount", attrs["unit_amount"])
    |> maybe_put_field_mapping("calories_per_unit", attrs["calories_per_unit"])
    |> maybe_put_field_mapping("protein_per_unit", attrs["protein_per_unit"])
    |> maybe_put_field_mapping("carbs_per_unit", attrs["carbs_per_unit"])
    |> maybe_put_field_mapping("fats_per_unit", attrs["fats_per_unit"])
    |> maybe_put_field_mapping("fiber_per_unit", attrs["fiber_per_unit"])
    |> maybe_put_field_mapping("sugar_per_unit", attrs["sugar_per_unit"])
    |> maybe_put_field_mapping("sodium_mg_per_unit", attrs["sodium_mg_per_unit"])
  end

  defp default_field_mapping(field_mapping, _attrs), do: field_mapping

  defp maybe_put_field_mapping(mapping, _field, nil), do: mapping

  defp maybe_put_field_mapping(mapping, field, value),
    do: Map.put(mapping, field, to_string(value))

  defp detect_context_kind(extraction, extracted_text) do
    context =
      extraction["screen_type"] || extraction["kind"] || extraction["context"] ||
        extraction["source_type"]

    cond do
      is_binary(context) and context != "" ->
        context

      Enum.any?(extracted_text, &String.contains?(String.downcase(&1), "dining")) ->
        "dining_hall_modal"

      true ->
        "nutrition_label"
    end
  end

  defp build_source_image_metadata(data_url, source_image_metadata) do
    source_image_metadata
    |> stringify_keys()
    |> Map.put_new(
      "captured_at",
      DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    )
    |> Map.put_new("mime_type", mime_type_from_data_url(data_url))
    |> Map.put_new("byte_size", byte_size_from_data_url(data_url))
  end

  defp mime_type_from_data_url("data:" <> rest) do
    rest
    |> String.split(";", parts: 2)
    |> List.first()
  end

  defp mime_type_from_data_url(_), do: "image/*"

  defp byte_size_from_data_url(data_url) do
    with [_prefix, encoded] <- String.split(data_url, ",", parts: 2),
         encoded <- String.replace(encoded, ~r/\s+/, ""),
         {:ok, binary} <- Base.decode64(encoded) do
      byte_size(binary)
    else
      _ -> nil
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_string(key), normalize_nested_value(value)}
    end)
  end

  defp stringify_keys(_), do: %{}

  defp normalize_nested_value(value) when is_map(value), do: stringify_keys(value)

  defp normalize_nested_value(value) when is_list(value),
    do: Enum.map(value, &normalize_nested_value/1)

  defp normalize_nested_value(value), do: value
end
