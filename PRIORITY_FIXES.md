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

- [todo] Resolve production checkout drift before the next deploy.
  Scope:
  - inspect the local modified files under `/opt/fittrack`
  - decide whether each production-only change should be committed, stashed, or discarded
  - confirm the checkout is clean before running `deploy.sh` again
  - keep `DATABASE_URL` as the production database source unless a separate `DB_PASSWORD` path is intentionally added
  - document the supported manual SQL check path, either parsed `DATABASE_URL` or `sudo -u postgres psql -d fittrack_prod`

- [todo] Add exercise video links for form reference in workout logging.
  Scope:
  - surface the best available video or external reference from the linked exercise template
  - keep links available from the active workout set logging flow without disrupting set entry
  - show a clear fallback when no form media exists
  - cover linked-template and no-media cases in LiveView tests

- [todo] Fix AI Workout Generator source-link autofill for YouTube, video, and article links.
  Scope:
  - source URL entry must trigger a clear Analyze Link or Generate path, not only LiveView validation
  - YouTube/video links should either autofill a structured draft from transcript/page content or show a useful failure message when content is unavailable
  - keep source-link generation from falling back to random generic WGER exercises
  - verify source-link drafts populate the review form with exercises, sets, reps, rest times, and set types when structured exercises are detected
  - add LiveView coverage for the YouTube/no-transcript failure state and the successful structured-source autofill path
