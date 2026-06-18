# Priority Fixes

This file is the execution queue for the highest-priority work.

## How To Use

- Use this file for active delivery work.
- Keep items here small enough to execute and verify.
- Move completed items to `FIXED_WORK.md`.
- Move deferred or larger roadmap items to `FUTURE_TASKS.md`.

## Status Key

- `[TODO]` not started
- `[IN-PROGRESS]` actively being worked
- `[BLOCKED]` cannot move without another fix or decision
- `[DONE]` completed and ready to move into `FIXED_WORK.md`

## Now

- [TODO] Repair normalized exercise taxonomy/source backfill.
  Scope:
  - backfill muscles and equipment for existing shared exercise templates.
  - populate source records and source visibility from WGER/source metadata.
  - verify admin filters show real muscle, equipment, and source options.
  - preserve existing templates and cached media.
  - report counts for templates, muscles, equipment, sources, media cached,
    missing, stale, and failed.
  - validate with the admin CRUD flow using a clearly temporary template,
    including create, edit, detail/review visibility, archive confirmation, and
    name/alias/media/category/difficulty filters.

- [DONE] Complete exercise media backfill for the normalized exercise library.
  Scope:
  - run the remaining production backfill in bounded batches.
  - keep local files under `EXERCISE_MEDIA_STORAGE_ROOT`.
  - record final fetched, cached, missing, skipped, stale, and failed counts.
  Result:
  - deployed bounded task `mix fittrack.exercise_media.backfill`.
  - set `EXERCISE_MEDIA_STORAGE_ROOT=/opt/fittrack/storage/exercise_media`.
  - production bounded run completed:
    `Fetched: 3`, `Cached: 0`, `Failed: 3`,
    `Exercises with no media: 363`.
  - failed rows are WGER `.MOV` videos rejected as `:file_too_large`.

- [DONE] Ensure cached exercise media displays consistently on library, detail,
  and workout logging views.
  Scope:
  - verify library cards, exercise detail pages, personal exercise pages, and
    workout logging references all prefer cached media.
  - preserve safe placeholders for missing, stale, or unsupported media.
  Result:
  - centralized user-facing media display in `FittrackWeb.ExerciseMediaHelper`.
  - normal views now prefer `/exercise-media/:id` cached media and avoid
    hotlinking remote media.
  - missing, stale, failed, skipped, unsupported, or invalid media falls back to
    safe placeholders.

- [DONE] Add import/admin reporting for fetched, cached, missing, skipped, and
  failed media.
  Scope:
  - make media health easy to inspect from admin workflows.
  - include enough source and status detail for follow-up cleanup.
  Result:
  - added admin media health report at `/admin/exercises/media`.
  - report includes status/source filters, exercise name, source URL, cached
    path/storage key, status reason/failure, and checked/fetched timestamps.

- [TODO] Add regression checks proving no active Sparky routes, assets, or
  references remain.
  Scope:
  - cover route helpers, asset manifests, app config, and deployment scripts.
  - allow clearly historical documentation references only.
