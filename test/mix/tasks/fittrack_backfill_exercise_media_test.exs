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
         },
         %{
           kind: "video",
           source: "wger",
           source_id: "too-large-video",
           source_exercise_id: "7001",
           source_url: "https://example.com/large.mov",
           is_primary: false,
           display_order: 4,
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

    def validate_url("https://example.com/large.mov", _opts), do: {:error, :file_too_large}
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

  defmodule ConcurrentMediaClientStub do
    def fetch_media(_opts) do
      {:ok,
       [
         media_record("valid-1", "https://example.com/concurrent-1.jpg", 0),
         media_record("valid-2", "https://example.com/concurrent-2.jpg", 1),
         media_record("missing-url", nil, 2),
         media_record("stale", "https://example.com/stale.jpg", 3),
         media_record("unsupported", "https://example.com/unsupported.webp", 4),
         media_record("invalid", "https://example.com/invalid.jpg", 5)
       ]}
    end

    defp media_record(source_id, source_url, display_order) do
      %{
        kind: "image",
        source: "wger",
        source_id: source_id,
        source_exercise_id: "7001",
        source_url: source_url,
        is_primary: display_order == 0,
        display_order: display_order,
        metadata: %{}
      }
    end
  end

  defmodule ConcurrentValidatorStub do
    def validate_url(url, http_client: test_pid)
        when url in [
               "https://example.com/concurrent-1.jpg",
               "https://example.com/concurrent-2.jpg"
             ] do
      send(test_pid, {:validating_media, url, self()})

      receive do
        {:continue_validation, ^url} ->
          {:ok, %{content_type: "image/jpeg", content_length: 12, media_type: "image"}}
      after
        1_000 ->
          {:error, :validation_timeout}
      end
    end

    def validate_url("https://example.com/stale.jpg", _opts), do: {:error, :stale_url}

    def validate_url("https://example.com/unsupported.webp", _opts),
      do: {:error, :unsupported_content_type}

    def validate_url("https://example.com/invalid.jpg", _opts), do: {:error, :invalid_url}
  end

  defmodule TimeoutMediaClientStub do
    def fetch_media(_opts) do
      {:ok,
       [
         %{
           kind: "image",
           source: "wger",
           source_id: "timeout",
           source_exercise_id: "7001",
           source_url: "https://example.com/timeout.jpg",
           is_primary: true,
           display_order: 0,
           metadata: %{}
         }
       ]}
    end
  end

  defmodule TimeoutValidatorStub do
    def validate_url(_url, _opts) do
      receive do
        :never -> :ok
      end
    end
  end

  defmodule BackfillOptionStub do
    def run(opts) do
      send(Process.get(:backfill_test_pid), {:backfill_opts, opts})

      {:ok,
       %{
         fetched: 0,
         cached: 0,
         already_cached: 0,
         missing: 0,
         skipped: 0,
         stale: 0,
         failed: 0,
         exercises_with_no_media: 0
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
              fetched: 5,
              cached: 1,
              already_cached: 0,
              missing: 1,
              skipped: 2,
              stale: 1,
              failed: 0,
              unsupported: 2
            }} = ExerciseMediaBackfill.run(opts)

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 5
    assert Repo.get_by!(ExerciseMedia, source_id: "image-1").cache_status == "cached"
    assert Repo.get_by!(ExerciseMedia, source_id: "missing-url").cache_status == "missing"
    assert Repo.get_by!(ExerciseMedia, source_id: "broken").cache_status == "stale"
    assert Repo.get_by!(ExerciseMedia, source_id: "video-1").cache_status == "unsupported"
    assert Repo.get_by!(ExerciseMedia, source_id: "too-large-video").cache_status == "unsupported"

    assert {:ok, %{already_cached: 1, missing: 1, skipped: 2, stale: 1, unsupported: 2}} =
             ExerciseMediaBackfill.run(opts)

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 5
    assert Repo.preload(template, :media).media |> length() == 5
  end

  test "processes records concurrently and aggregates all report counts" do
    opts = [
      media_client: ConcurrentMediaClientStub,
      validator: ConcurrentValidatorStub,
      cache: CacheStub,
      http_client: self(),
      media_type: "all",
      limit: 10,
      concurrency: 2
    ]

    task = Task.async(fn -> ExerciseMediaBackfill.run(opts) end)

    assert_receive {:validating_media, "https://example.com/concurrent-1.jpg", first_worker}
    assert_receive {:validating_media, "https://example.com/concurrent-2.jpg", second_worker}
    assert first_worker != second_worker

    send(first_worker, {:continue_validation, "https://example.com/concurrent-1.jpg"})
    send(second_worker, {:continue_validation, "https://example.com/concurrent-2.jpg"})

    assert {:ok,
            %{
              fetched: 6,
              cached: 2,
              already_cached: 0,
              missing: 1,
              skipped: 2,
              stale: 1,
              failed: 0,
              unsupported: 2
            }} = Task.await(task)
  end

  test "backfills existing media rows in bounded database batches", %{template: template} do
    {:ok, _valid} =
      %ExerciseMedia{}
      |> ExerciseMedia.changeset(%{
        exercise_template_id: template.id,
        kind: "image",
        source: "wger",
        source_id: "db-valid",
        source_exercise_id: "7001",
        source_url: "https://example.com/valid.jpg",
        cache_status: "remote_only"
      })
      |> Repo.insert()

    {:ok, missing} =
      %ExerciseMedia{}
      |> ExerciseMedia.changeset(%{
        exercise_template_id: template.id,
        kind: "image",
        source: "wger",
        source_id: "db-missing",
        source_exercise_id: "7001",
        source_url: nil,
        cache_status: "remote_only"
      })
      |> Repo.insert()

    {:ok, untouched} =
      %ExerciseMedia{}
      |> ExerciseMedia.changeset(%{
        exercise_template_id: template.id,
        kind: "image",
        source: "wger",
        source_id: "db-later",
        source_exercise_id: "7001",
        source_url: "https://example.com/broken.jpg",
        cache_status: "remote_only"
      })
      |> Repo.insert()

    assert {:ok,
            %{
              fetched: 2,
              cached: 1,
              missing: 1,
              batches: 1
            }} =
             ExerciseMediaBackfill.run(
               validator: ValidatorStub,
               cache: CacheStub,
               batch_size: 2,
               max_batches: 1,
               concurrency: 1
             )

    assert Repo.get_by!(ExerciseMedia, source_id: "db-valid").cache_status == "cached"
    assert Repo.reload!(missing).cache_status == "missing"
    assert Repo.reload!(untouched).cache_status == "remote_only"
  end

  test "dry run reports work without writing media rows" do
    opts = [
      media_client: MediaClientStub,
      validator: ValidatorStub,
      cache: CacheStub,
      media_type: "all",
      limit: 10,
      dry_run: true,
      concurrency: 2
    ]

    assert {:ok,
            %{
              fetched: 5,
              cached: 1,
              missing: 1,
              skipped: 2,
              stale: 1,
              failed: 0,
              unsupported: 2
            }} = ExerciseMediaBackfill.run(opts)

    assert Repo.aggregate(ExerciseMedia, :count, :id) == 0
  end

  test "task timeouts are reported as failed records" do
    opts = [
      media_client: TimeoutMediaClientStub,
      validator: TimeoutValidatorStub,
      cache: CacheStub,
      media_type: "all",
      limit: 1,
      concurrency: 1,
      timeout: 10
    ]

    assert {:ok, %{fetched: 1, failed: 1}} = ExerciseMediaBackfill.run(opts)
  end

  test "task passes concurrency option to the backfill" do
    Process.put(:backfill_test_pid, self())

    capture_io(fn ->
      Mix.Tasks.Fittrack.BackfillExerciseMedia.run(
        ["--concurrency", "7", "--limit", "1", "--batch-size", "25", "--max-batches", "3"],
        BackfillOptionStub
      )
    end)

    assert_received {:backfill_opts, opts}
    assert Keyword.fetch!(opts, :concurrency) == 7
    assert Keyword.fetch!(opts, :batch_size) == 25
    assert Keyword.fetch!(opts, :max_batches) == 3
  after
    Process.delete(:backfill_test_pid)
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
          unsupported: 0,
          batches: 1,
          exercises_with_no_media: 0
        })
      end)

    assert output =~ "Exercise media backfill complete"
    assert output =~ "Fetched: 1"
    assert output =~ "Cached: 1"
  end
end
