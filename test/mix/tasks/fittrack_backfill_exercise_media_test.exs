defmodule Mix.Tasks.FittrackBackfillExerciseMediaTest do
  use Fittrack.DataCase

  import ExUnit.CaptureIO

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMediaBackfill
  alias Fittrack.Training.ExerciseTemplate

  defmodule MediaClientStub do
    def fetch_media(_opts) do
      {:ok,
       [
         %{
           kind: "image",
           source: "wger",
           source_id: "image-1",
           source_exercise_id: "7001",
           source_url: "https://example.com/valid.jpg",
           is_primary: true,
           display_order: 0,
           metadata: %{}
         },
         %{
           kind: "image",
           source: "wger",
           source_id: "missing-url",
           source_exercise_id: "7001",
           source_url: nil,
           is_primary: false,
           display_order: 1,
           metadata: %{}
         },
         %{
           kind: "image",
           source: "wger",
           source_id: "broken",
           source_exercise_id: "7001",
           source_url: "https://example.com/broken.jpg",
           is_primary: false,
           display_order: 2,
           metadata: %{}
         },
         %{
           kind: "video",
           source: "wger",
           source_id: "video-1",
           source_exercise_id: "7001",
           source_url: "https://example.com/video.mp4",
           is_primary: false,
           display_order: 3,
           metadata: %{}
         }
       ]}
    end
  end

  defmodule ValidatorStub do
    def validate_url("https://example.com/valid.jpg", _opts),
      do: {:ok, %{content_type: "image/jpeg", content_length: 12, media_type: "image"}}

    def validate_url("https://example.com/broken.jpg", _opts), do: {:error, :stale_url}

    def validate_url("https://example.com/video.mp4", _opts),
      do: {:error, :unsupported_content_type}
  end

  defmodule CacheStub do
    def cache(_media, _opts) do
      {:ok,
       %{
         local_path: "1/checksum.jpg",
         storage_key: "1/checksum.jpg",
         checksum: "checksum",
         content_type: "image/jpeg",
         file_size: 12
       }}
    end
  end

  setup do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        source_id: 7001,
        name: "Backfill Row",
        primary_muscle: "Back",
        equipment: "Cable"
      })
      |> Repo.insert()

    %{template: template}
  end

  test "backfills media, reports counts, and is idempotent", %{template: template} do
    opts = [
      media_client: MediaClientStub,
      validator: ValidatorStub,
      cache: CacheStub,
      media_type: "all",
      limit: 10
    ]

    assert {:ok,
            %{
              fetched: 4,
              cached: 1,
              already_cached: 0,
              missing: 1,
              skipped: 1,
              stale: 1,
              failed: 0
            }} = ExerciseMediaBackfill.run(opts)

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 4
    assert Repo.get_by!(ExerciseMedia, source_id: "image-1").cache_status == "cached"
    assert Repo.get_by!(ExerciseMedia, source_id: "missing-url").cache_status == "missing"
    assert Repo.get_by!(ExerciseMedia, source_id: "broken").cache_status == "stale"
    assert Repo.get_by!(ExerciseMedia, source_id: "video-1").cache_status == "skipped"

    assert {:ok, %{already_cached: 1, missing: 1, skipped: 1, stale: 1}} =
             ExerciseMediaBackfill.run(opts)

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 4
    assert Repo.preload(template, :media).media |> length() == 4
  end

  test "task prints the expected report" do
    output =
      capture_io(fn ->
        Mix.Tasks.Fittrack.BackfillExerciseMedia.print_report(%{
          fetched: 1,
          cached: 1,
          already_cached: 0,
          missing: 0,
          skipped: 0,
          stale: 0,
          failed: 0,
          exercises_with_no_media: 0
        })
      end)

    assert output =~ "Exercise media backfill completed"
    assert output =~ "Fetched remote records: 1"
    assert output =~ "Cached: 1"
  end
end
