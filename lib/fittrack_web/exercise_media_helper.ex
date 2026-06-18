defmodule FittrackWeb.ExerciseMediaHelper do
  @moduledoc """
  Centralized exercise media display helpers for user-facing templates.
  """

  use FittrackWeb, :verified_routes

  alias Fittrack.Training.Exercise
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseTemplate

  @image_kinds ["image", "thumbnail"]

  def exercise_media_url(subject, opts \\ []) do
    kinds = Keyword.get(opts, :kinds, @image_kinds)

    case pick_cached_media(subject, kinds) do
      %ExerciseMedia{} = media -> ~p"/exercise-media/#{media.id}"
      nil -> placeholder_url(subject)
    end
  end

  def exercise_media_urls(subject, opts \\ []) do
    kinds = Keyword.get(opts, :kinds, @image_kinds)

    urls =
      subject
      |> media_items()
      |> Enum.filter(&displayable_cached_media?(&1, kinds))
      |> sort_media()
      |> Enum.map(&~p"/exercise-media/#{&1.id}")

    case urls do
      [] -> if(url = placeholder_url(subject), do: [url], else: [])
      urls -> urls
    end
  end

  def exercise_media_reference(subject, opts \\ []) do
    label = Keyword.get(opts, :label, "Form reference")

    with %ExerciseMedia{} = media <- pick_cached_media(subject, ["video"]) do
      %{kind: :internal, url: ~p"/exercise-media/#{media.id}", label: "Form video"}
    else
      nil ->
        case pick_cached_media(subject, @image_kinds) do
          %ExerciseMedia{} = media ->
            %{kind: :internal, url: ~p"/exercise-media/#{media.id}", label: label}

          nil ->
            nil
        end
    end
  end

  defp pick_cached_media(subject, kinds) do
    subject
    |> media_items()
    |> Enum.filter(&displayable_cached_media?(&1, kinds))
    |> sort_media()
    |> List.first()
  end

  defp media_items(%ExerciseTemplate{media: media}) when is_list(media), do: media

  defp media_items(%Exercise{source_template: %ExerciseTemplate{media: media}})
       when is_list(media),
       do: media

  defp media_items(media) when is_list(media), do: media
  defp media_items(_subject), do: []

  defp placeholder_url(%ExerciseTemplate{id: id}) when not is_nil(id),
    do: ~p"/exercise-template-images/#{id}"

  defp placeholder_url(%Exercise{source_template: %ExerciseTemplate{id: id}}) when not is_nil(id),
    do: ~p"/exercise-template-images/#{id}"

  defp placeholder_url(_subject), do: nil

  defp displayable_cached_media?(%ExerciseMedia{} = media, kinds) do
    media.cache_status == "cached" and media.kind in kinds and is_binary(media.local_path) and
      not is_nil(media.id)
  end

  defp displayable_cached_media?(_media, _kinds), do: false

  defp sort_media(media) do
    Enum.sort_by(media, fn item ->
      {not item.is_primary, item.display_order || 0, item.id || 0}
    end)
  end
end
