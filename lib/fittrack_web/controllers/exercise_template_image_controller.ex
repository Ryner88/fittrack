defmodule FittrackWeb.ExerciseTemplateImageController do
  use FittrackWeb, :controller

  alias Fittrack.Training

  def show(conn, %{"id" => id}) do
    with %{image_url: image_url} when is_binary(image_url) <- Training.get_exercise_template(id),
         {:ok, uri} <- validate_image_uri(image_url),
         {:ok, response} <- image_http_client().get(URI.to_string(uri), receive_timeout: 10_000),
         %{status: status, body: body} when status in 200..299 and is_binary(body) <- response do
      content_type = response_content_type(response) || "image/jpeg"

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "private, max-age=86400")
      |> send_resp(200, body)
    else
      nil ->
        send_resp(conn, 404, "Not Found")

      %{image_url: _} ->
        send_resp(conn, 404, "Not Found")

      {:error, :invalid_url} ->
        send_resp(conn, 404, "Not Found")

      _error ->
        send_resp(conn, 502, "Image unavailable")
    end
  end

  defp validate_image_uri(image_url) do
    uri = image_url |> String.trim() |> URI.parse()

    if uri.scheme in ["http", "https"] and is_binary(uri.host) do
      {:ok, %{uri | scheme: "https", port: nil}}
    else
      {:error, :invalid_url}
    end
  end

  defp image_http_client do
    Application.get_env(:fittrack, :exercise_image_http_client, Req)
  end

  defp response_content_type(%{headers: headers}) do
    headers
    |> List.wrap()
    |> Enum.find_value(fn
      {"content-type", value} -> value
      {"Content-Type", value} -> value
      _header -> nil
    end)
    |> case do
      nil -> nil
      value when is_binary(value) -> value |> String.split(";") |> List.first()
    end
  end
end
