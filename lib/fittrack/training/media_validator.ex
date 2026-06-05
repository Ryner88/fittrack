defmodule Fittrack.Training.MediaValidator do
  @moduledoc """
  Validates remote exercise media before it is cached.
  """

  @image_types ~w(image/jpeg image/png image/webp image/gif)
  @video_types ~w(video/mp4 video/webm video/quicktime)
  @default_max_bytes 15 * 1024 * 1024

  def validate_url(url, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)
    http_client = Keyword.get(opts, :http_client, Req)

    with {:ok, uri} <- validate_uri(url),
         {:ok, metadata} <- request_metadata(http_client, URI.to_string(uri), max_bytes) do
      {:ok, metadata}
    end
  end

  def validate_url_metadata(response, max_bytes \\ @default_max_bytes) do
    response
    |> validate_response_metadata(max_bytes)
    |> validate_body_size(response, max_bytes)
  end

  def supported_content_type?(content_type) when is_binary(content_type) do
    normalized = normalize_content_type(content_type)
    normalized in @image_types or normalized in @video_types
  end

  def media_type(content_type) when is_binary(content_type) do
    normalized = normalize_content_type(content_type)

    cond do
      normalized in @image_types -> "image"
      normalized in @video_types -> "video"
      true -> nil
    end
  end

  def extension(content_type) when is_binary(content_type) do
    case normalize_content_type(content_type) do
      "image/jpeg" -> ".jpg"
      "image/png" -> ".png"
      "image/webp" -> ".webp"
      "image/gif" -> ".gif"
      "video/mp4" -> ".mp4"
      "video/webm" -> ".webm"
      "video/quicktime" -> ".mov"
      _ -> ".bin"
    end
  end

  def normalize_content_type(content_type) when is_binary(content_type) do
    content_type
    |> String.split(";")
    |> List.first()
    |> String.trim()
    |> String.downcase()
  end

  def normalize_content_type(_content_type), do: nil

  defp validate_uri(url) when is_binary(url) do
    uri = url |> String.trim() |> URI.parse()

    if uri.scheme in ["http", "https"] and is_binary(uri.host) do
      {:ok, uri}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_uri(_url), do: {:error, :missing_url}

  defp request_metadata(http_client, url, max_bytes) do
    case http_client.head(url, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in [404, 410] ->
        {:error, :stale_url}

      {:ok, %{status: status} = response} when status in 200..299 ->
        validate_response_metadata(response, max_bytes)

      _head_error ->
        request_metadata_with_get(http_client, url, max_bytes)
    end
  end

  defp request_metadata_with_get(http_client, url, max_bytes) do
    case http_client.get(url, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in [404, 410] ->
        {:error, :stale_url}

      {:ok, %{status: status} = response} when status in 200..299 ->
        response
        |> validate_response_metadata(max_bytes)
        |> validate_body_size(response, max_bytes)

      {:ok, %{status: status}} ->
        {:error, {:bad_status, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp validate_response_metadata(response, max_bytes) do
    content_type = response |> response_header("content-type") |> normalize_content_type_value()
    content_length = response |> response_header("content-length") |> parse_content_length()

    cond do
      is_nil(content_type) or not supported_content_type?(content_type) ->
        {:error, :unsupported_content_type}

      content_length == 0 ->
        {:error, :zero_byte_file}

      is_integer(content_length) and content_length > max_bytes ->
        {:error, :file_too_large}

      true ->
        {:ok,
         %{
           content_type: normalize_content_type(content_type),
           content_length: content_length,
           media_type: media_type(content_type)
         }}
    end
  end

  defp validate_body_size({:ok, metadata}, %{body: body}, max_bytes) when is_binary(body) do
    cond do
      byte_size(body) == 0 ->
        {:error, :zero_byte_file}

      byte_size(body) > max_bytes ->
        {:error, :file_too_large}

      true ->
        {:ok, %{metadata | content_length: metadata.content_length || byte_size(body)}}
    end
  end

  defp validate_body_size(result, _response, _max_bytes), do: result

  defp response_header(%{headers: headers}, key) when is_map(headers) do
    headers[String.downcase(key)] || headers[key]
  end

  defp response_header(%{headers: headers}, key) when is_list(headers) do
    key = String.downcase(key)

    Enum.find_value(headers, fn
      {header_key, value} when is_binary(header_key) ->
        if String.downcase(header_key) == key, do: value

      _header ->
        nil
    end)
  end

  defp response_header(_response, _key), do: nil

  defp normalize_content_type_value([value | _]), do: normalize_content_type_value(value)
  defp normalize_content_type_value(value) when is_binary(value), do: value
  defp normalize_content_type_value(_value), do: nil

  defp parse_content_length([value | _]), do: parse_content_length(value)

  defp parse_content_length(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_content_length(_value), do: nil
end
