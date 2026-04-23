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

- `[done]` Stabilize the nutrition test suite and LiveView flows.
  Target:
  - `Fittrack.NutritionTest`
  - `FittrackWeb.NutritionLiveTest`
  Done when:
  - nutrition flows pass reliably
  - `mix precommit` is green without unrelated workaround changes
  Completed:
  - meal persistence and LiveView redirects stabilized
  - targeted nutrition suites pass
  - `mix precommit` is green

- `[done]` Reconcile outstanding worktree edits before stacking more feature work.
  Files previously called out:
  - `README.md`
  - `config/runtime.exs`
  - `lib/fittrack/training/exercise_template_importer.ex`
  - `test/fittrack_web/live/exercise_live_test.exs`
  Done when:
  - each edit is either intentionally kept in the branch or split out
  - branch scope is clear
  Completed:
  - worktree is clean on `main`
  - the previously called-out files have no outstanding diffs
  - branch scope is clear

- `[done]` Finish hardening the WGER exercise template importer.
  Remaining focus:
  - validate behavior against real WGER payload variations
  - improve importer reporting for failed records
  - confirm safe legacy-template adoption on production-like data
  Done when:
  - importer is safe to rerun
  - importer output is trustworthy
  Completed:
  - natural failure reporting verified with a broader live sample
  - deterministic CLI failure fixture added for repeatable inspection
  - importer behavior covered with focused tests

## Next

- `[todo]` Complete the full nutrition module.
  Scope:
  - meal logging
  - weekly planner
  - nutrition dashboard

- `[todo]` Expand workout logging to capture performed:
  - sets
  - reps
  - weight

- `[todo]` Complete Workout History with a dependable calendar view of completed sessions.

- `[in-progress]` Finish the nutrition import checklist:
  - add barcode-based nutrition import
  - add supported-website nutrition import flow
  - add import review/confirmation screen
  - add source tracking for imported food data

## Later

- `[todo]` Remember frequently imported campus foods.
- `[todo]` Auto-suggest recent dining hall items.
- `[todo]` Favorite cafeteria meals.
- `[todo]` Add custom macro goals based on TDEE.
- `[todo]` Add water intake tracking.
- `[todo]` Add nutrition/workout export.
