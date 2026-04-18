defmodule Fittrack.Nutrition.UrlImportParser do
  @moduledoc """
  Fetches supported dining-site pages and extracts nutrition values from JSON-LD.
  """

  @supported_hosts [
    "mcdonalds.com",
    "starbucks.com",
    "panerabread.com",
    "sweetgreen.com",
    "chipotle.com"
  ]
  @measurement_units MapSet.new(["g", "gram", "grams", "kg", "oz", "ml", "l", "lb", "serving"])

  def parse(url) when is_binary(url) do
    with {:ok, uri} <- validate_url(url),
         true <- supported_host?(uri.host) || {:error, :unsupported_host},
         {:ok, html} <- fetch_html(url),
         {:ok, attrs} <- extract_nutrition(html) do
      {:ok, Map.put(attrs, "source_url", url)}
    end
  end

  def parse(_), do: {:error, :invalid_url}

  def supported_hosts, do: @supported_hosts

  defp validate_url(url) do
    uri = URI.parse(String.trim(url))

    if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" do
      {:ok, uri}
    else
      {:error, :invalid_url}
    end
  end

  defp supported_host?(host) do
    Enum.any?(@supported_hosts, fn supported ->
      host == supported or String.ends_with?(host, ".#{supported}")
    end)
  end

  defp fetch_html(url) do
    headers = [{"user-agent", "Fittrack/0.1 url-import (contact: local-app)"}]

    case http_client().get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{status: _status}} -> {:error, :fetch_failed}
      {:error, _error} -> {:error, :fetch_failed}
    end
  end

  defp extract_nutrition(html) do
    html
    |> extract_json_ld_blocks()
    |> Enum.flat_map(&decode_json_ld/1)
    |> Enum.find_value({:error, :nutrition_not_found}, fn item ->
      case normalize_item(item) do
        nil -> false
        attrs -> {:ok, attrs}
      end
    end)
  end

  defp extract_json_ld_blocks(html) do
    Regex.scan(~r/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/is, html)
    |> Enum.map(fn [_, content] -> String.trim(content) end)
  end

  defp decode_json_ld(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> flatten_json_ld(decoded)
      _ -> []
    end
  end

  defp flatten_json_ld(items) when is_list(items), do: Enum.flat_map(items, &flatten_json_ld/1)

  defp flatten_json_ld(%{"@graph" => graph} = item),
    do: [Map.delete(item, "@graph") | flatten_json_ld(graph)]

  defp flatten_json_ld(item) when is_map(item), do: [item]
  defp flatten_json_ld(_), do: []

  defp normalize_item(%{} = item) do
    nutrition = item["nutrition"] || item[:nutrition]
    name = item["name"] || item[:name]

    with %{} = nutrition <- nutrition,
         true <- is_binary(name) and String.trim(name) != "" do
      {unit_amount, unit} =
        (nutrition["servingSize"] || item["servingSize"])
        |> parse_serving_size()

      %{
        "name" => String.trim(name),
        "unit" => normalize_unit(unit),
        "unit_amount" => decimal_string(unit_amount),
        "quantity" => decimal_string(unit_amount),
        "calories_per_unit" => decimal_string(parse_nutrition_number(nutrition["calories"])),
        "protein_per_unit" => decimal_string(parse_nutrition_number(nutrition["proteinContent"])),
        "carbs_per_unit" =>
          decimal_string(parse_nutrition_number(nutrition["carbohydrateContent"])),
        "fats_per_unit" => decimal_string(parse_nutrition_number(nutrition["fatContent"]))
      }
    else
      _ -> nil
    end
  end

  defp normalize_item(_), do: nil

  defp parse_serving_size(serving_size) when is_binary(serving_size) do
    case Regex.run(~r/(\d+(?:[.,]\d+)?)\s*([[:alpha:]]+)/u, serving_size) do
      [_, amount, unit] ->
        {to_decimal(String.replace(amount, ",", ".")), String.downcase(unit)}

      _ ->
        {Decimal.new(1), "serving"}
    end
  end

  defp parse_serving_size(_), do: {Decimal.new(1), "serving"}

  defp normalize_unit(unit) when is_binary(unit) do
    if MapSet.member?(@measurement_units, unit), do: unit, else: "serving"
  end

  defp parse_nutrition_number(nil), do: Decimal.new(0)
  defp parse_nutrition_number(%Decimal{} = value), do: value
  defp parse_nutrition_number(value) when is_integer(value), do: Decimal.new(value)
  defp parse_nutrition_number(value) when is_float(value), do: Decimal.from_float(value)

  defp parse_nutrition_number(value) when is_binary(value) do
    case Regex.run(~r/(\d+(?:[.,]\d+)?)/, value) do
      [_, amount] -> to_decimal(String.replace(amount, ",", "."))
      _ -> Decimal.new(0)
    end
  end

  defp parse_nutrition_number(_), do: Decimal.new(0)

  defp decimal_string(value) do
    value
    |> to_decimal()
    |> Decimal.round(2)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp to_decimal(_), do: Decimal.new(0)

  defp http_client do
    Application.get_env(:fittrack, :url_import_http_client, Req)
  end
end
