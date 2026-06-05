defmodule Fittrack.Training.ExerciseTemplateMediaTest do
  use Fittrack.DataCase

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseTemplate

  test "stores multiple cached media records for one exercise template" do
    template = template_fixture()

    {:ok, first} =
      Training.upsert_exercise_media(template, %{
        kind: "image",
        source: "wger",
        source_id: "media-1",
        source_exercise_id: to_string(template.source_id),
        source_url: "https://wger.de/media/1.jpg",
        cache_status: "cached",
        local_path: "#{template.id}/one.jpg",
        content_hash: "same-hash",
        mime_type: "image/jpeg",
        file_size: 10,
        is_primary: true
      })

    {:ok, second} =
      Training.upsert_exercise_media(template, %{
        kind: "image",
        source: "wger",
        source_id: "media-2",
        source_exercise_id: to_string(template.source_id),
        source_url: "https://wger.de/media/2.jpg",
        cache_status: "cached",
        local_path: "#{template.id}/two.jpg",
        content_hash: "same-hash",
        mime_type: "image/jpeg",
        file_size: 10,
        display_order: 1
      })

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 2
    assert Training.primary_cached_media(Repo.preload(template, :media)).id == first.id
    assert second.content_hash == first.content_hash
  end

  test "does not duplicate media on repeated upsert" do
    template = template_fixture()

    attrs = %{
      kind: "image",
      source: "wger",
      source_id: "repeatable",
      source_exercise_id: to_string(template.source_id),
      source_url: "https://wger.de/media/repeatable.jpg"
    }

    assert {:ok, _media} = Training.upsert_exercise_media(template, attrs)
    assert {:ok, _media} = Training.upsert_exercise_media(template, attrs)
    assert Repo.aggregate(ExerciseMedia, :count, :id) == 1
  end

  defp template_fixture do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        source_id: System.unique_integer([:positive]),
        name: "Media Test Exercise",
        primary_muscle: "Back",
        equipment: "Barbell"
      })
      |> Repo.insert()

    template
  end
end
