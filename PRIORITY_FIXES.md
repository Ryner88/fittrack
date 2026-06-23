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

- [IN-PROGRESS] Finish exercise media population for the normalized exercise
  library.
  Scope:
  - refresh missing WGER source metadata and media references for existing
    shared templates without creating duplicate templates.
  - run the remaining production cache work in bounded batches.
  - keep local files under `EXERCISE_MEDIA_STORAGE_ROOT`.
  - decide whether oversized WGER `.MOV` files should remain failed, use a
    larger configured limit, or be handled outside the cache pipeline.
  - record final fetched, cached, already-cached, missing, skipped,
    unsupported, stale, failed, and exercises-with-no-media counts.
  Progress:
  - the bounded `mix fittrack.exercise_media.backfill` task is deployed.
  - production storage is configured at
    `/opt/fittrack/storage/exercise_media`.
  - limited production verification runs succeeded, but full media population
    is not complete.
  - the latest documented bounded result is `Fetched: 3`, `Cached: 0`,
    `Failed: 3`, and `Exercises with no media: 363`; the three failures are
    oversized WGER `.MOV` videos.

- [TODO] Repair remaining normalized exercise taxonomy/source metadata.
  Scope:
  - backfill muscles and equipment for existing shared exercise templates.
  - populate non-media source records and source visibility from WGER metadata.
  - verify admin filters show real muscle, equipment, and source options.
  - preserve existing templates and cached media.
  - report counts for templates, muscles, equipment, sources, media cached,
    missing, stale, and failed.

- [TODO] Add regression checks proving no active Sparky routes, assets, or
  references remain.
  Scope:
  - cover route helpers, asset manifests, app config, and deployment scripts.
  - allow clearly historical documentation references only.
