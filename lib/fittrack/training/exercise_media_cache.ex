defmodule Fittrack.Training.ExerciseMediaCache do
  @moduledoc """
  Downloads validated exercise media into app-owned storage.
  """

  alias Fittrack.Training.MediaValidator

  @default_max_bytes 15 * 1024 * 1024

  def cache(%{exercise_template_id: exercise_template_id, source_url: url}, opts \\ []) do
    http_client = Keyword.get(opts, :http_client, Req)
    root = Keyword.get(opts, :storage_root, storage_root())
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)

    with {:ok, uri} <- validate_cache_uri(url),
         {:ok, response} <- http_client.get(URI.to_string(uri), receive_timeout: 15_000),
         {:ok, metadata} <- validate_response(response, max_bytes) do
      body = response.body
      checksum = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
      extension = MediaValidator.extension(metadata.content_type)
      relative_path = Path.join([to_string(exercise_template_id), "#{checksum}#{extension}"])
      absolute_path = Path.join(root, relative_path)

      File.mkdir_p!(Path.dirname(absolute_path))
      File.write!(absolute_path, body)

      {:ok,
       metadata
       |> Map.put(:checksum, checksum)
       |> Map.put(:file_size, byte_size(body))
       |> Map.put(:local_path, relative_path)
       |> Map.put(:storage_key, relative_path)}
    end
  end

  def absolute_path(local_path) when is_binary(local_path) do
    Path.join(storage_root(), local_path)
  end

  def storage_root do
    Application.get_env(:fittrack, :exercise_media_storage_root) ||
      Path.join(System.tmp_dir!(), "fittrack/exercise_media")
  end

  defp validate_cache_uri(url) when is_binary(url) do
    uri = url |> String.trim() |> URI.parse()

    if uri.scheme in ["http", "https"] and is_binary(uri.host) do
      {:ok, uri}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_cache_uri(_url), do: {:error, :missing_url}

  defp validate_response(%{status: status}, _max_bytes) when status in [404, 410],
    do: {:error, :stale_url}

  defp validate_response(%{status: status, body: body} = response, max_bytes)
       when status in 200..299 and is_binary(body) do
    with {:ok, metadata} <- MediaValidator.validate_url_metadata(response, max_bytes) do
      if byte_size(body) > 0 do
        {:ok, %{metadata | content_length: byte_size(body)}}
      else
        {:error, :zero_byte_file}
      end
    end
  end

  defp validate_response(%{status: status}, _max_bytes), do: {:error, {:bad_status, status}}
  defp validate_response(_response, _max_bytes), do: {:error, :invalid_response}
end
