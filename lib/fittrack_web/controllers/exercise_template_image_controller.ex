defmodule FittrackWeb.ExerciseTemplateImageController do
  use FittrackWeb, :controller

  alias Fittrack.Training

  def show(conn, %{"id" => id}) do
    case Training.get_exercise_template(id) do
      nil ->
        fallback_image(conn, "Exercise")

      template ->
        case Training.primary_cached_media(template) do
          nil -> fallback_image(conn, template.name)
          media -> send_cached_media_or_fallback(conn, media, template.name)
        end
    end
  end

  def media(conn, %{"id" => id}) do
    with media when not is_nil(media) <- Training.get_exercise_media(id),
         {:ok, path} <- Training.exercise_media_path(media) do
      conn
      |> put_resp_content_type(media.mime_type || "application/octet-stream")
      |> put_resp_header("cache-control", "public, max-age=31536000")
      |> send_file(200, path)
    else
      _error ->
        fallback_image(conn, "Exercise")
    end
  end

  defp send_cached_media_or_fallback(conn, media, name) do
    with {:ok, path} <- Training.exercise_media_path(media) do
      conn
      |> put_resp_content_type(media.mime_type || "application/octet-stream")
      |> put_resp_header("cache-control", "public, max-age=31536000")
      |> send_file(200, path)
    else
      _error -> fallback_image(conn, name)
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
