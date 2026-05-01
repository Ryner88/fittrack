defmodule FittrackWeb.ExerciseTemplateImageController do
  use FittrackWeb, :controller

  alias Fittrack.Training

  def show(conn, %{"id" => id}) do
    case Training.get_exercise_template(id) do
      %{name: name, image_url: image_url} when is_binary(image_url) ->
        proxy_or_fallback(conn, name, image_url)

      nil ->
        fallback_image(conn, "Exercise")

      %{name: name} when is_binary(name) ->
        fallback_image(conn, name)

      _template ->
        fallback_image(conn, "Exercise")
    end
  end

  defp proxy_or_fallback(conn, name, image_url) do
    with {:ok, uri} <- validate_image_uri(image_url),
         {:ok, response} <- image_http_client().get(URI.to_string(uri), receive_timeout: 10_000),
         %{status: status, body: body} when status in 200..299 and is_binary(body) <- response do
      content_type = response_content_type(response) || "image/jpeg"

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "private, max-age=86400")
      |> send_resp(200, body)
    else
      _error -> fallback_image(conn, name)
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

  defp fallback_image(conn, name) do
    svg = fallback_svg(name)

    conn
    |> put_resp_content_type("image/svg+xml")
    |> put_resp_header("cache-control", "private, max-age=3600")
    |> send_resp(200, svg)
  end

  defp fallback_svg(name) do
    safe_name =
      name
      |> to_string()
      |> String.slice(0, 48)
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480" role="img" aria-label="#{safe_name}">
      <rect width="640" height="480" fill="#f1f5f9"/>
      <circle cx="320" cy="190" r="72" fill="#cbd5e1"/>
      <path d="M190 375c28-72 74-108 130-108s102 36 130 108" fill="none" stroke="#94a3b8" stroke-width="34" stroke-linecap="round"/>
      <text x="320" y="430" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="28" font-weight="700" fill="#475569">#{safe_name}</text>
    </svg>
    """
  end
end
