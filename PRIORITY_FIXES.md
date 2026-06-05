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

- [todo] Fix AI Workout Generator source-link autofill for YouTube, video, and article links.
  Scope:
  - source URL entry must trigger a clear Analyze Link or Generate path, not only LiveView validation
  - YouTube/video links should either autofill a structured draft from transcript/page content or show a useful failure message when content is unavailable
  - keep source-link generation from falling back to random generic WGER exercises
  - verify source-link drafts populate the review form with exercises, sets, reps, rest times, and set types when structured exercises are detected
  - add LiveView coverage for the YouTube/no-transcript failure state and the successful structured-source autofill path
