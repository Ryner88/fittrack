defmodule Fittrack.Training.ExerciseMediaBackfill do
  @moduledoc """
  Backfills WGER exercise media into cached, app-owned storage.
  """

  import Ecto.Query

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMediaCache
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.MediaValidator
  alias Fittrack.Training.Wger.MediaClient

  @empty_report %{
    fetched: 0,
    cached: 0,
    already_cached: 0,
    missing: 0,
    skipped: 0,
    stale: 0,
    failed: 0,
    exercises_with_no_media: 0
  }

  def run(opts \\ []) do
    opts = normalize_opts(opts)

    with {:ok, records} <- fetch_records(opts) do
      report =
        records
        |> maybe_filter_by_exercise(opts)
        |> process_records(opts)
        |> merge_reports()
        |> Map.update!(:fetched, &(&1 + length(records)))
        |> Map.put(:exercises_with_no_media, exercises_with_no_cached_media())

      {:ok, report}
    end
  end

  defp fetch_records(opts) do
    client = Keyword.get(opts, :media_client, MediaClient)

    client.fetch_media(
      limit: Keyword.get(opts, :limit),
      media_type: Keyword.get(opts, :media_type),
      api_key: Keyword.get(opts, :api_key),
      http_client: Keyword.get(opts, :http_client, Req)
    )
  end

  defp process_records(records, opts) do
    records
    |> Task.async_stream(&process_record(&1, opts),
      max_concurrency: Keyword.get(opts, :concurrency),
      timeout: Keyword.get(opts, :timeout, :infinity),
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, report} -> report
      {:exit, _reason} -> increment(@empty_report, :failed)
    end)
  end

  defp process_record(record, opts) do
    cond do
      blank?(record.source_url) ->
        record_missing(record, opts, "missing URL")

      record.kind not in allowed_media_kinds(opts) ->
        record_skipped(record, opts, "unsupported media type")

      true ->
        case Training.find_template_for_wger_media(record) do
          %ExerciseTemplate{} = template -> persist_and_cache(template, record, opts)
          nil -> increment(@empty_report, :missing)
        end
    end
  end

  defp persist_and_cache(template, record, opts) do
    media = upsert_initial_media(template, record, opts)

    cond do
      media.cache_status == "cached" and not Keyword.get(opts, :force_check, false) ->
        increment(@empty_report, :already_cached)

      Keyword.get(opts, :skip_download, false) ->
        mark_media(media, %{cache_status: "skipped", failure_reason: "download skipped"}, opts)
        increment(@empty_report, :skipped)

      true ->
        validate_and_cache(media, opts)
    end
  end

  defp validate_and_cache(media, opts) do
    validator = Keyword.get(opts, :validator, MediaValidator)
    cache = Keyword.get(opts, :cache, ExerciseMediaCache)
    http_client = Keyword.get(opts, :http_client, Req)
    checked_at = DateTime.utc_now() |> DateTime.truncate(:second)

    case validator.validate_url(media.source_url, http_client: http_client) do
      {:ok, _metadata} ->
        case cache.cache(media, http_client: http_client) do
          {:ok, cache_attrs} ->
            mark_media(
              media,
              %{
                cache_status: "cached",
                failure_reason: nil,
                checked_at: checked_at,
                cached_at: checked_at,
                local_path: cache_attrs.local_path,
                storage_key: cache_attrs.storage_key,
                content_hash: cache_attrs.checksum,
                mime_type: cache_attrs.content_type,
                file_size: cache_attrs.file_size
              },
              opts
            )

            increment(@empty_report, :cached)

          {:error, :stale_url} ->
            mark_media(media, stale_attrs("stale URL", checked_at), opts)
            increment(@empty_report, :stale)

          {:error, reason} ->
            mark_media(media, failure_attrs(reason, checked_at), opts)
            increment(@empty_report, :failed)
        end

      {:error, :missing_url} ->
        mark_media(media, missing_attrs("missing URL", checked_at), opts)
        increment(@empty_report, :missing)

      {:error, :invalid_url} ->
        mark_media(media, failure_attrs(:invalid_url, checked_at), opts)
        increment(@empty_report, :failed)

      {:error, :unsupported_content_type} ->
        mark_media(media, skipped_attrs("unsupported content type", checked_at), opts)
        increment(@empty_report, :skipped)

      {:error, :stale_url} ->
        mark_media(media, stale_attrs("stale URL", checked_at), opts)
        increment(@empty_report, :stale)

      {:error, reason} ->
        mark_media(media, failure_attrs(reason, checked_at), opts)
        increment(@empty_report, :failed)
    end
  end

  defp upsert_initial_media(template, record, opts) do
    attrs =
      record
      |> Map.take([
        :kind,
        :source,
        :source_id,
        :source_exercise_id,
        :source_url,
        :provider_attribution,
        :is_primary,
        :display_order,
        :metadata
      ])
      |> Map.put_new(:cache_status, "remote_only")

    if Keyword.get(opts, :dry_run, false) do
      struct(ExerciseMedia, Map.put(attrs, :exercise_template_id, template.id))
    else
      {:ok, media} = Training.upsert_exercise_media(template, attrs)
      media
    end
  end

  defp record_missing(record, opts, reason) do
    with %ExerciseTemplate{} = template <- Training.find_template_for_wger_media(record) do
      media = upsert_initial_media(template, record, opts)

      mark_media(
        media,
        missing_attrs(reason, DateTime.utc_now() |> DateTime.truncate(:second)),
        opts
      )
    end

    increment(@empty_report, :missing)
  end

  defp record_skipped(record, opts, reason) do
    with %ExerciseTemplate{} = template <- Training.find_template_for_wger_media(record) do
      media = upsert_initial_media(template, record, opts)

      mark_media(
        media,
        skipped_attrs(reason, DateTime.utc_now() |> DateTime.truncate(:second)),
        opts
      )
    end

    increment(@empty_report, :skipped)
  end

  defp mark_media(media, attrs, opts) do
    if Keyword.get(opts, :dry_run, false) do
      :ok
    else
      Training.update_exercise_media(media, attrs)
    end
  end

  defp missing_attrs(reason, checked_at),
    do: %{cache_status: "missing", failure_reason: reason, checked_at: checked_at}

  defp skipped_attrs(reason, checked_at),
    do: %{cache_status: "skipped", failure_reason: reason, checked_at: checked_at}

  defp stale_attrs(reason, checked_at),
    do: %{cache_status: "stale", failure_reason: reason, checked_at: checked_at}

  defp failure_attrs(reason, checked_at),
    do: %{cache_status: "failed", failure_reason: inspect(reason), checked_at: checked_at}

  defp maybe_filter_by_exercise(records, opts) do
    case Keyword.get(opts, :exercise_id) do
      nil ->
        records

      exercise_id ->
        Enum.filter(records, &(&1.source_exercise_id == to_string(exercise_id)))
    end
  end

  defp exercises_with_no_cached_media do
    ExerciseTemplate
    |> join(:left, [template], media in assoc(template, :media),
      on: media.cache_status == "cached" and not is_nil(media.local_path)
    )
    |> where([_template, media], is_nil(media.id))
    |> Repo.aggregate(:count, :id)
  end

  defp allowed_media_kinds(opts) do
    case Keyword.get(opts, :media_type, "all") do
      "image" -> ["image", "thumbnail"]
      "video" -> ["video"]
      _all -> ["image", "thumbnail", "video"]
    end
  end

  defp normalize_opts(opts) do
    opts
    |> Keyword.put_new(:limit, 100)
    |> Keyword.put_new(:media_type, "all")
    |> Keyword.update(:concurrency, 3, fn
      concurrency when is_integer(concurrency) and concurrency > 0 -> concurrency
      _invalid -> 3
    end)
  end

  defp merge_reports(reports) do
    Enum.reduce(reports, @empty_report, fn report, acc ->
      Map.merge(acc, report, fn _key, left, right -> left + right end)
    end)
  end

  defp increment(report, key), do: Map.update!(report, key, &(&1 + 1))
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)
end
