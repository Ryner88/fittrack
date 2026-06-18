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

  @eligible_cache_statuses ~w(remote_only queued missing failed stale)

  @empty_report %{
    fetched: 0,
    cached: 0,
    already_cached: 0,
    missing: 0,
    skipped: 0,
    stale: 0,
    failed: 0,
    unsupported: 0,
    batches: 0,
    exercises_with_no_media: 0
  }

  def run(opts \\ []) do
    opts = normalize_opts(opts)

    result =
      if remote_media_source?(opts) do
        run_remote_sync(opts)
      else
        run_database_backfill(opts)
      end

    case result do
      {:ok, report} ->
        {:ok, Map.put(report, :exercises_with_no_media, exercises_with_no_cached_media())}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_remote_sync(opts) do
    with {:ok, records} <- fetch_remote_records(opts) do
      records = maybe_filter_by_exercise(records, opts)

      report =
        records
        |> process_records(opts)
        |> merge_reports()
        |> Map.update!(:fetched, &(&1 + length(records)))
        |> Map.update!(:batches, &(&1 + if(records == [], do: 0, else: 1)))

      {:ok, report}
    end
  end

  defp run_database_backfill(opts) do
    report = process_database_batches(opts, [], 0, @empty_report)
    {:ok, report}
  end

  defp process_database_batches(opts, processed_ids, batch_count, report) do
    cond do
      reached_batch_limit?(opts, batch_count) ->
        report

      reached_limit?(opts, report.fetched) ->
        report

      true ->
        batch_size = next_batch_size(opts, report.fetched)
        records = fetch_database_records(opts, processed_ids, batch_size)

        case records do
          [] ->
            report

          records ->
            batch_report =
              records
              |> process_records(opts)
              |> merge_reports()
              |> Map.update!(:fetched, &(&1 + length(records)))
              |> Map.update!(:batches, &(&1 + 1))

            processed_ids = processed_ids ++ Enum.map(records, & &1.id)

            process_database_batches(
              opts,
              processed_ids,
              batch_count + 1,
              merge_reports([report, batch_report])
            )
        end
    end
  end

  defp fetch_remote_records(opts) do
    client = Keyword.get(opts, :media_client, MediaClient)

    client.fetch_media(
      limit: Keyword.get(opts, :limit) || 100,
      media_type: Keyword.get(opts, :media_type),
      api_key: Keyword.get(opts, :api_key),
      http_client: Keyword.get(opts, :http_client, Req)
    )
  end

  defp fetch_database_records(opts, processed_ids, batch_size) do
    ExerciseMedia
    |> where([media], media.cache_status in ^eligible_statuses(opts))
    |> where([media], media.kind in ^allowed_media_kinds(opts))
    |> maybe_exclude_processed_media(processed_ids)
    |> maybe_filter_media_by_exercise(Keyword.get(opts, :exercise_id))
    |> order_by([media],
      asc: fragment("coalesce(?, ?)", media.checked_at, media.updated_at),
      asc: media.id
    )
    |> limit(^batch_size)
    |> Repo.all()
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

  defp process_record(%ExerciseMedia{} = media, opts) do
    checked_at = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      blank?(media.source_url) ->
        mark_media(media, missing_attrs("missing URL", checked_at), opts)
        increment(@empty_report, :missing)

      media.kind not in allowed_media_kinds(opts) ->
        mark_media(media, skipped_attrs("media type skipped for this backfill", checked_at), opts)
        increment(@empty_report, :skipped)

      local_file_exists?(media) and media.cache_status == "cached" ->
        mark_media(media, %{checked_at: checked_at, failure_reason: nil}, opts)
        increment(@empty_report, :already_cached)

      local_file_exists?(media) ->
        mark_media(media, existing_cached_attrs(media, checked_at), opts)
        increment(@empty_report, :cached)

      media.cache_status == "cached" ->
        mark_media(media, stale_attrs("cached file missing", checked_at), opts)
        increment(@empty_report, :stale)

      Keyword.get(opts, :skip_download, false) ->
        mark_media(media, skipped_attrs("download skipped", checked_at), opts)
        increment(@empty_report, :skipped)

      true ->
        validate_and_cache(media, opts, checked_at)
    end
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
        mark_media(
          media,
          skipped_attrs("download skipped", DateTime.utc_now() |> DateTime.truncate(:second)),
          opts
        )

        increment(@empty_report, :skipped)

      true ->
        validate_and_cache(media, opts, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end

  defp validate_and_cache(media, opts, checked_at) do
    validator = Keyword.get(opts, :validator, MediaValidator)
    cache = Keyword.get(opts, :cache, ExerciseMediaCache)
    http_client = Keyword.get(opts, :http_client, Req)

    case validator.validate_url(media.source_url, http_client: http_client) do
      {:ok, _metadata} ->
        cache_valid_media(media, opts, cache, http_client, checked_at)

      {:error, :missing_url} ->
        mark_media(media, missing_attrs("missing URL", checked_at), opts)
        increment(@empty_report, :missing)

      {:error, :invalid_url} ->
        mark_unsupported(media, "unsupported URL", checked_at, opts)

      {:error, :unsupported_content_type} ->
        mark_unsupported(media, "unsupported content type", checked_at, opts)

      {:error, :stale_url} ->
        mark_media(media, stale_attrs("stale URL", checked_at), opts)
        increment(@empty_report, :stale)

      {:error, reason} ->
        mark_media(media, failure_attrs(reason, checked_at), opts)
        increment(@empty_report, :failed)
    end
  end

  defp cache_valid_media(media, opts, cache, http_client, checked_at) do
    if Keyword.get(opts, :dry_run, false) do
      increment(@empty_report, :cached)
    else
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

        {:error, :invalid_url} ->
          mark_unsupported(media, "unsupported URL", checked_at, opts)

        {:error, :unsupported_content_type} ->
          mark_unsupported(media, "unsupported content type", checked_at, opts)

        {:error, reason} ->
          mark_media(media, failure_attrs(reason, checked_at), opts)
          increment(@empty_report, :failed)
      end
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

  defp mark_unsupported(media, reason, checked_at, opts) do
    mark_media(media, unsupported_attrs(reason, checked_at), opts)

    @empty_report
    |> increment(:skipped)
    |> increment(:unsupported)
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

  defp unsupported_attrs(reason, checked_at),
    do: %{cache_status: "unsupported", failure_reason: reason, checked_at: checked_at}

  defp failure_attrs(reason, checked_at),
    do: %{cache_status: "failed", failure_reason: inspect(reason), checked_at: checked_at}

  defp existing_cached_attrs(media, checked_at) do
    %{
      cache_status: "cached",
      failure_reason: nil,
      checked_at: checked_at,
      cached_at: media.cached_at || checked_at
    }
  end

  defp maybe_filter_by_exercise(records, opts) do
    case Keyword.get(opts, :exercise_id) do
      nil -> records
      exercise_id -> Enum.filter(records, &(&1.source_exercise_id == to_string(exercise_id)))
    end
  end

  defp exercises_with_no_cached_media do
    ExerciseTemplate
    |> where(
      [template],
      fragment(
        "NOT EXISTS (SELECT 1 FROM exercise_media em WHERE em.exercise_template_id = ? AND em.cache_status = 'cached' AND em.local_path IS NOT NULL)",
        template.id
      )
    )
    |> Repo.aggregate(:count, :id)
  end

  defp eligible_statuses(opts) do
    if Keyword.get(opts, :force_check, false) do
      ["cached" | @eligible_cache_statuses]
    else
      @eligible_cache_statuses
    end
  end

  defp maybe_exclude_processed_media(query, []), do: query

  defp maybe_exclude_processed_media(query, processed_ids) do
    where(query, [media], media.id not in ^processed_ids)
  end

  defp maybe_filter_media_by_exercise(query, nil), do: query

  defp maybe_filter_media_by_exercise(query, exercise_id) do
    source_exercise_id = to_string(exercise_id)

    where(
      query,
      [media],
      media.source_exercise_id == ^source_exercise_id or
        media.exercise_template_id == ^exercise_id
    )
  end

  defp allowed_media_kinds(opts) do
    case Keyword.get(opts, :media_type, "all") do
      "image" -> ["image", "thumbnail"]
      "video" -> ["video"]
      _all -> ["image", "thumbnail", "video"]
    end
  end

  defp local_file_exists?(%ExerciseMedia{local_path: local_path}) when is_binary(local_path) do
    with {:ok, path} <- ExerciseMediaCache.safe_absolute_path(local_path) do
      File.regular?(path)
    else
      _error -> false
    end
  end

  defp local_file_exists?(_media), do: false

  defp normalize_opts(opts) do
    opts
    |> Keyword.put_new(:media_type, "all")
    |> normalize_positive_integer(:batch_size, 50)
    |> normalize_positive_integer(:max_batches, 1)
    |> normalize_optional_positive_integer(:limit)
    |> Keyword.update(:concurrency, 3, fn
      concurrency when is_integer(concurrency) and concurrency > 0 -> concurrency
      _invalid -> 3
    end)
  end

  defp normalize_positive_integer(opts, key, default) do
    Keyword.update(opts, key, default, fn
      value when is_integer(value) and value > 0 -> value
      value when is_binary(value) -> parse_positive_integer(value, default)
      _invalid -> default
    end)
  end

  defp normalize_optional_positive_integer(opts, key) do
    Keyword.update(opts, key, nil, fn
      nil -> nil
      value when is_integer(value) and value > 0 -> value
      value when is_binary(value) -> parse_positive_integer(value, nil)
      _invalid -> nil
    end)
  end

  defp parse_positive_integer(value, default) do
    case Integer.parse(to_string(value)) do
      {integer, ""} when integer > 0 -> integer
      _invalid -> default
    end
  end

  defp remote_media_source?(opts) do
    Keyword.get(opts, :sync_remote, false) or Keyword.has_key?(opts, :media_client)
  end

  defp reached_batch_limit?(opts, batch_count) do
    case Keyword.get(opts, :max_batches) do
      nil -> false
      max_batches -> batch_count >= max_batches
    end
  end

  defp reached_limit?(opts, fetched) do
    case Keyword.get(opts, :limit) do
      nil -> false
      limit -> fetched >= limit
    end
  end

  defp next_batch_size(opts, fetched) do
    batch_size = Keyword.fetch!(opts, :batch_size)

    case Keyword.get(opts, :limit) do
      nil -> batch_size
      limit -> min(batch_size, limit - fetched)
    end
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
