# Priority Fixes

This file is the execution queue for the highest-priority work.

## How To Use

- Use this file for active delivery work.
- Keep items here small enough to execute and verify.
- Move completed items to `FIXED_WORK.md`.
- Move deferred or larger roadmap items to `FUTURE_TASKS.md`.

## Status Key

- `[todo]` not started
- `[in-progress]` actively being worked
- `[blocked]` cannot move without another fix or decision
- `[done]` completed and ready to move into `FIXED_WORK.md`

## Now

- `[todo]` Implement exercise media backfill concurrency.
   Scope:
   - `Fittrack.Training.ExerciseMediaBackfill` already receives/parses
     `:concurrency`, but processing is still sequential.
   - Use `Task.async_stream/3` with a safe default concurrency of `3`.
   - Preserve `dry_run`, `skip_download`, `force_check`, `limit`, `media_type`,
     and `exercise_id` behavior.
   - Preserve idempotent upserts.
   - Aggregate report counts deterministically:
     `fetched`, `cached`, `already_cached`, `missing`, `skipped`, `stale`,
     `failed`, and `exercises_with_no_media`.
   - Handle task exits/timeouts as failed records where possible.
   - Do not change storage behavior:
     files stay under `EXERCISE_MEDIA_STORAGE_ROOT`, `local_path`/`storage_key`
     stay relative, no `priv/static`, and no DB binaries.
   Verification:
   - `mix format`
   - `mix precommit`
   - tests proving concurrent cached/missing/skipped/stale/failed counts
   - tests proving `already_cached` and `dry_run` behavior still work
   - test proving the Mix task passes the concurrency option through

- `[todo]` Run limited production exercise media backfill verification.
   Scope:
   - Run only after concurrency passes locally.
   - Use production env safely with `PHX_SERVER` unset.
   - Start with dry run.
   - Then run a small image-only import with limit and concurrency.
   - Verify files are created under `/opt/fittrack/storage/exercise_media`.
   - Verify `local_path`/`storage_key` are relative paths only.
   - Verify `/exercise-media/:id` serves cached media.
   - Verify missing files fall back safely.
   - Do not touch production data outside the intended backfill path.
   Verification:
   - dry-run report is captured before any write
   - small image-only run reports expected fetched/cached/missing/skipped/failed
     counts
   - DB rows use relative `local_path`/`storage_key`
   - cached files exist under `/opt/fittrack/storage/exercise_media`
   - `/exercise-media/:id` returns cached media or fallback safely

- `[todo]` Remove leftover ignored Sparky runtime folder from production filesystem.
   Scope:
   - This is an external filesystem cleanup, not a Git change.
   - Active repo search found no Sparky references in `lib`, `config`, `priv`,
     `assets`, `README.md`, `deploy.sh`, or `mix.exs`.
   - Local `sparkyfitness/` is absent.
   - Remove `/opt/fittrack/sparkyfitness` when comfortable.
   - Confirm `rg -i "sparky|sparkyfitness"` has no active app matches after
     cleanup.
   - No production database changes.
   Verification:
   - `/opt/fittrack/sparkyfitness` no longer exists or has been archived outside
     the deploy directory
   - `rg -i "sparky|sparkyfitness"` has no active app matches
   - `git status --short` in `/opt/fittrack` remains clean
