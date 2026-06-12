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
