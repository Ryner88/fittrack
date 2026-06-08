# Exercise Media Backfill

This document defines the intended behavior for the exercise media backfill against
the current normalized exercise library.

## Current Library Structure

The shared exercise catalog is centered on `exercise_templates`.

- `exercise_templates` stores the canonical shared exercise record. WGER imports
  currently use `source_id` for the WGER exercise id, plus optional
  `exercise_template_sources` rows for source-specific ids and payloads.
- `exercise_muscles`, `exercise_equipment`, `exercise_template_muscles`, and
  `exercise_template_equipment` store normalized classification metadata.
- `exercise_aliases`, `exercise_variations`, and `exercise_substitutions` store
  search and relationship metadata.
- `exercises` stores user-owned exercises and can link back to a source template.
- `exercise_media` stores media records linked to `exercise_templates`.

Template media should be app-owned once cached. UI code should render media
through `/exercise-media/:id`, not directly from WGER URLs, except for explicitly
allowed external video form references in workout logging.

The legacy `exercise_templates.image_url` field may remain as import compatibility
metadata, but the production media path is `exercise_media`.

## Required Schema

The media backfill requires the normalized library migration and cache/audit
fields to be present.

Required `exercise_media` fields:

- identity and matching: `exercise_template_id`, `source`, `source_id`,
  `source_exercise_id`, `source_url`
- media description: `kind`, `provider_attribution`, `is_primary`,
  `display_order`, `metadata`, `duration_seconds`
- cache state: `cache_status`, `cached_at`, `checked_at`, `failure_reason`
- stored file data: `local_path`, `storage_key`, `content_hash`, `mime_type`,
  `file_size`, `width`, `height`

Required statuses:

- `remote_only`: media row exists but the file is not cached yet.
- `queued`: reserved for future async workers.
- `cached`: file is stored locally and can be served by the app.
- `missing`: source record exists but has no usable URL.
- `skipped`: source URL is valid enough to record, but should not be downloaded
  because it is unsupported or the operator requested `--skip-download`.
- `failed`: attempted validation or download failed for a non-stale reason.
- `stale`: source URL is gone or known broken, such as HTTP 404 or 410.

## Source Of Truth

WGER is the current remote source of truth for catalog media.

The backfill fetches remote records from:

- `https://wger.de/api/v2/exerciseimage/`
- `https://wger.de/api/v2/video/`

The WGER API key is optional and read from `WGER_API_KEY` by the Mix task.

Every fetched WGER record must be normalized to:

- `kind`: `image`, `thumbnail`, or `video`
- `source`: `wger`
- `source_id`: the WGER media row id
- `source_exercise_id`: the WGER exercise or exercise-base id
- `source_url`: the image/video URL
- `provider_attribution`
- `is_primary`
- `display_order`
- `metadata`: license, author, UUID, and other non-empty provider metadata

## WGER Import Plan

The WGER media import should run as a bounded, repeatable backfill.

1. Fetch WGER image/video references.
   - Request `exerciseimage` records for images.
   - Request `video` records for videos.
   - Follow WGER pagination until `--limit` is reached or the endpoint is
     exhausted.
   - Normalize each remote row before doing local database work.
   - Increment `fetched` for each remote media row returned before local
     filtering.

2. Match each media reference to a local exercise template.
   - Use the exact WGER exercise id matching rules below.
   - Do not create templates during media import.
   - If no local template matches, do not download the file and increment
     `missing`.

3. Skip invalid or broken references before caching.
   - Blank URLs become `missing`.
   - Unsupported media kinds or content types become `skipped`.
   - HTTP 404/410 URLs become `stale` and are not retried in the same run.
   - Invalid URLs, request errors, zero-byte files, and oversized files become
     `failed`.

4. Cache working files in app-owned storage.
   - Download only validated image/video files.
   - Write the file under `EXERCISE_MEDIA_STORAGE_ROOT` using the
     `<exercise_template_id>/<sha256>.<extension>` layout.
   - Store only the relative path in `exercise_media.local_path` and
     `exercise_media.storage_key`.
   - Mark successful rows as `cached` and record checksum, MIME type, file size,
     `checked_at`, and `cached_at`.

5. Report the run outcome.
   - Always report `fetched`, `cached`, `missing`, `skipped`, and `failed`.
   - Also report `already_cached`, `stale`, and `exercises_with_no_media` so the
     operator can distinguish healthy idempotency from broken source data.

## Matching Rules

Backfill must only attach media to an existing local template when the WGER
exercise id matches local source metadata.

Match order:

1. Parse `source_exercise_id` as an integer and match
   `exercise_templates.source_id`.
2. If no template matches, find an `exercise_template_sources` row where
   `source = "wger"` and `external_id = source_exercise_id`.
3. If neither match exists, do not create a template. Count the record as
   `missing` from the media-backfill perspective.

The media backfill must not perform fuzzy name matching. Fuzzy matching belongs
in template import/review work, not media attachment, because attaching media to
the wrong exercise is worse than leaving the exercise without media.

## Upsert Rules

For a matched template, upsert an `exercise_media` row.

Lookup order:

1. Existing row with the same `source` and `source_id`.
2. Existing row with the same `source_url` when source identity is absent.

Upserted remote fields may update on repeated runs:

- `kind`
- `source`
- `source_id`
- `source_exercise_id`
- `source_url`
- `provider_attribution`
- `is_primary`
- `display_order`
- `metadata`

Cached fields must not be downgraded by importer or backfill refreshes. If an
existing row is `cached`, and an incoming provider row only says `remote_only`,
preserve:

- `cache_status`
- `local_path`
- `storage_key`
- `content_hash`
- `cached_at`
- `file_size`
- `mime_type`

Repeated runs must be idempotent: they may refresh metadata and audit fields,
but they must not create duplicate media rows for the same provider media.

## Validation And Download

The backfill must validate remote URLs before writing cache state.

Validation rules:

- blank URL: `missing`
- non-HTTP/HTTPS URL or missing host: `failed`
- HTTP 404 or 410: `stale`
- unsupported content type: `skipped`
- zero-byte file: `failed`
- file larger than the configured max bytes: `failed`
- any other request failure: `failed`

Supported content types:

- images: `image/jpeg`, `image/png`, `image/webp`, `image/gif`
- videos: `video/mp4`, `video/webm`, `video/quicktime`

The download step writes only validated files into app-owned storage.

Storage rules:

- Root directory comes from `EXERCISE_MEDIA_STORAGE_ROOT`.
- Runtime default is `/opt/fittrack/storage/exercise_media`.
- Test/dev fallback may use a temp directory when the runtime env var is absent.
- Stored path shape is `<exercise_template_id>/<sha256>.<extension>`.
- `local_path` and `storage_key` store the relative path, not an absolute path.
- The app serves cached files through `/exercise-media/:id`.

On successful cache:

- set `cache_status` to `cached`
- clear `failure_reason`
- set `checked_at` and `cached_at`
- set `local_path`, `storage_key`, `content_hash`, `mime_type`, and `file_size`

## Operator Options

The Mix task is `mix fittrack.backfill_exercise_media`.

Supported options:

- `--dry-run`: fetch and report without writing database rows or files.
- `--limit N`: fetch up to N remote media records.
- `--exercise-id ID`: process only media whose WGER source exercise id matches
  ID. This is a WGER id, not a local `exercise_templates.id`.
- `--force-check`: revalidate and redownload records even when already cached.
- `--skip-download`: upsert source rows but mark downloadable records as
  `skipped`.
- `--media-type image`: fetch image endpoint only.
- `--media-type video`: fetch video endpoint only.
- `--media-type all`: fetch image and video endpoints.
- `--concurrency N`: intended worker concurrency for validation/download.

Current implementation parses `--concurrency`, but processing is sequential.
Before documenting concurrency as operationally available, either implement it
with bounded `Task.async_stream/3` or remove the option from the public task.

## Report Semantics

The task report must include:

- `fetched`: number of remote records fetched before local filtering.
- `cached`: records successfully downloaded into app-owned storage.
- `already_cached`: records skipped because they are already cached and
  `--force-check` was not provided.
- `missing`: records with no source URL or no local template match.
- `skipped`: unsupported media or intentionally skipped downloads.
- `stale`: source URLs that are gone or broken.
- `failed`: validation/download failures not covered by missing, skipped, or
  stale.
- `exercises_with_no_media`: local templates with no cached media file.

For `--exercise-id`, `fetched` should remain the number of records fetched from
the remote source, while other counters should describe only records processed
after filtering.

## UI Contract

Library browsing and detail pages:

- show cached `image` or `thumbnail` media only
- sort primary media first, then `display_order`, then row id
- show a placeholder when no cached image exists

Workout logging:

- prefer cached `video`
- then allow a safe external `video` URL for `remote_only` or `queued` video
  rows
- then fall back to cached image/thumbnail
- show `No form reference available` when no usable media exists

Controllers:

- `/exercise-media/:id` must serve only cached local files.
- Missing files, uncached rows, missing rows, or invalid media ids should return
  the existing fallback image rather than proxying remote content.

## Operational Sequence

For a production backfill:

1. Deploy code containing all required migrations.
2. Run migrations and verify `exercise_media` has the required cache columns.
3. Verify `EXERCISE_MEDIA_STORAGE_ROOT` points to persistent writable storage.
4. Import or refresh exercise templates so WGER ids exist locally.
5. Run `MIX_ENV=prod mix fittrack.backfill_exercise_media --dry-run --limit 50`.
6. Review report counts for unexpectedly high `missing`, `failed`, or `stale`.
7. Run a small real batch, for example
   `MIX_ENV=prod mix fittrack.backfill_exercise_media --limit 50`.
8. Verify cached files exist on disk and `/exercise-media/:id` serves them.
9. Run the full backfill in batches or with bounded concurrency once implemented.
10. Re-run the task periodically with `--force-check` only when intentionally
    refreshing remote media health.

## Verification Gates

Before considering the backfill complete in an environment, verify:

- migrations include `20260529154852_create_normalized_exercise_library`
- migrations include `20260605144506_add_cache_fields_to_exercise_media`
- `exercise_media` has `local_path`, `source_exercise_id`, `checked_at`, and
  `display_order`
- WGER-backed templates have `source_id` or `exercise_template_sources` rows
- dry-run can fetch WGER media and produce a report
- a real run creates or updates `exercise_media`
- at least one row reaches `cache_status = "cached"`
- cached files exist under `EXERCISE_MEDIA_STORAGE_ROOT`
- `/exercise-media/:id` returns the cached file with a cache-control header
- Exercise Library pages render cached images or placeholders without remote
  proxying
- repeated runs do not duplicate media rows or downgrade cached rows

## Current Gaps To Resolve

The current codebase is close to this contract, but these gaps should be handled
before treating the backfill as fully production-defined:

- Local development database drift: this checkout has the normalized library
  migration applied but not `20260605144506_add_cache_fields_to_exercise_media`,
  so the local `exercise_media` table is missing cache columns required by the
  current code.
- The task parses `--concurrency`, but the backfill currently processes records
  sequentially.
- `exercises_with_no_media` should be verified after the cache-field migration
  is present in the target database.
- The task docs should clarify that `--exercise-id` is a WGER exercise id, not a
  local template id.
