defmodule Fittrack.Training.Wger.MediaClient do
  @moduledoc """
  Fetches and normalizes WGER exercise media records.
  """

  @image_url "https://wger.de/api/v2/exerciseimage/"
  @video_url "https://wger.de/api/v2/video/"

  def fetch_media(opts \\ []) do
    limit = opts |> Keyword.get(:limit, 100) |> max(0)
    media_type = Keyword.get(opts, :media_type, "all")
    api_key = Keyword.get(opts, :api_key)
    http_client = Keyword.get(opts, :http_client, Req)
    headers = headers(api_key)

    endpoints(media_type)
    |> Enum.reduce_while({:ok, []}, fn {kind, url}, {:ok, acc} ->
      remaining = limit - length(acc)

      if remaining <= 0 do
        {:halt, {:ok, acc}}
      else
        case fetch_page(url, kind, headers, remaining, [], http_client) do
          {:ok, records} -> {:cont, {:ok, acc ++ records}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

  def normalize_record(record, kind) when is_map(record) do
    source_url = first_present([record["image"], record["video"], record["url"]])

    source_exercise_id =
      first_present([record["exercise"], record["exercise_base"], record["exercise_id"]])

    %{
      kind: normalize_kind(kind, source_url),
      source: "wger",
      source_id: present_string(record["id"]),
      source_exercise_id: present_string(source_exercise_id),
      source_url: present_string(source_url),
      provider_attribution: first_present([record["license_author"], record["author"]]),
      is_primary: record["is_main"] == true or record["main"] == true,
      display_order: record["position"] || 0,
      metadata:
        record
        |> Map.take(["license", "license_author", "author", "uuid"])
        |> Enum.reject(fn {_key, value} -> blank?(value) end)
        |> Map.new()
    }
  end

  def normalize_record(_record, kind) do
    %{
      kind: normalize_kind(kind, nil),
      source: "wger",
      source_id: nil,
      source_exercise_id: nil,
      source_url: nil,
      is_primary: false,
      display_order: 0,
      metadata: %{}
    }
  end

  defp fetch_page(_url, _kind, _headers, 0, acc, _http_client), do: {:ok, acc}

  defp fetch_page(url, kind, headers, remaining, acc, http_client) do
    case http_client.get(url, headers: headers) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        with {:ok, results, next_url} <- extract_page(body) do
          normalized =
            results
            |> Enum.map(&normalize_record(&1, kind))
            |> Enum.take(remaining)

          updated_acc = acc ++ normalized
          next_remaining = remaining - length(normalized)

          if next_url && next_remaining > 0 do
            fetch_page(next_url, kind, headers, next_remaining, updated_acc, http_client)
          else
            {:ok, updated_acc}
          end
        end

      {:ok, %{status: status}} ->
        {:error, {:bad_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_page(%{"results" => results} = body) when is_list(results) do
    {:ok, results, body["next"]}
  end

  defp extract_page(results) when is_list(results), do: {:ok, results, nil}
  defp extract_page(body), do: {:error, {:unexpected_body, body}}

  defp endpoints("image"), do: [{"image", @image_url}]
  defp endpoints("video"), do: [{"video", @video_url}]
  defp endpoints("all"), do: [{"image", @image_url}, {"video", @video_url}]
  defp endpoints(_media_type), do: [{"image", @image_url}, {"video", @video_url}]

  defp normalize_kind("video", _url), do: "video"
  defp normalize_kind("image", _url), do: "image"

  defp normalize_kind(_kind, url) when is_binary(url) do
    if String.contains?(url, "video"), do: "video", else: "image"
  end

  defp normalize_kind(_kind, _url), do: "image"

  defp headers(nil), do: []
  defp headers(""), do: []
  defp headers(api_key), do: [{"Authorization", "Token #{api_key}"}]

  defp first_present(values), do: Enum.find_value(values, &present_string/1)

  defp present_string(value) when is_integer(value), do: Integer.to_string(value)

  defp present_string(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp present_string(_value), do: nil

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)
end
