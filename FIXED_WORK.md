# Fixed Work

This file is a release-notes style summary of work that has already been completed
or materially addressed on the recent branches.

## How To Use

- Use this file as the completed-work log.
- Keep entries outcome-focused, not task-list focused.
- When possible, include commit references for traceability.
- Do not keep open work here; open work belongs in `PRIORITY_FIXES.md` or `FUTURE_TASKS.md`.

## Now

### Workout History IA And Completed-Only Calendar

- Commit references:
  - uncommitted worktree changes

- Renamed the authenticated top navigation entry from `Workouts` to `History` and pointed it at the completed-workout History page.
- Kept History in the existing authenticated router scope:
  - `scope "/", FittrackWeb`
  - `pipe_through [:browser, :require_authenticated_user]`
  - `live_session :require_authenticated_user`
  This is required because the page reads user-scoped workout data through `current_scope`.
- Reworked Workout History so it is completed-record focused:
  - active sessions without sets no longer appear in the completed calendar
  - selected-day details list only completed workouts
  - row-level action remains historical with `View details`
  - no `Repeat` action appears on History
- Added contextual header CTA behavior:
  - no active workout: `Start workout` and `Browse plans`
  - active workout: `Resume workout`
- Added summary stats to History:
  - workouts this week
  - average duration
  - total volume
  - streak
- Fixed calendar edge handling for months that begin without leading padding.
- Added regression coverage for:
  - History nav label and destination
  - Start/Browse vs Resume CTA behavior
  - completed-only History calendar and selected-day details
  - active-workout context query
  - completed-workout date/range queries
- Deferred plan and muscle-split filters until workout records have explicit plan linkage and reliable per-session muscle aggregation.

### Nutrition Stabilization And Importer Follow-Through

- Commit references:
  - `64ec96c` Harden WGER importer pagination and legacy adoption
  - `1d5263d` Stabilize nutrition flows and importer diagnostics
  - `bab822c` Merge nutrition stabilization and importer fixes
  - `65d98ff` Update priority fix tracker

- Stabilized nutrition context behavior so meal persistence and associated meal items save and reload consistently.
- Fixed nutrition LiveView flows so meal and meal-plan creation redirect paths are reliable and testable.
- Cleared the nutrition-specific test failures in:
  - `Fittrack.NutritionTest`
  - `FittrackWeb.NutritionLiveTest`
- Verified `mix precommit` passes on the merged `main` branch without workaround changes.
- Closed out the previously flagged worktree reconciliation item:
  - `README.md`
  - `config/runtime.exs`
  - `lib/fittrack/training/exercise_template_importer.ex`
  - `test/fittrack_web/live/exercise_live_test.exs`
  all ended up intentionally integrated with a clean worktree on `main`.
- Hardened importer diagnostics further by:
  - verifying real failure reporting against a broader live sample
  - adding a deterministic CLI failure fixture for repeatable inspection
  - extending importer coverage for failure metadata and production-like adoption paths

### WGER Importer

- Commit references:
  - `8614277` Improve WGER exercise template imports
  - `07ec8e1` Refine WGER exercise template importer behavior

- Added `source_id` support for exercise templates.
- Added importer normalization for translated WGER content.
- Sanitized imported notes into plain text instead of storing raw HTML.
- Added a cleanup task for legacy imported notes.
- Fixed the high-risk legacy adoption issue:
  the importer no longer binds a WGER `source_id` to an existing legacy template unless the match is safe.
- Fixed the pagination gap:
  the importer now follows WGER `next` links instead of silently stopping after page 1.
- Fixed the API key mismatch:
  `WGER_API_KEY` is now optional in the importer path, matching the task documentation.
- Added regression coverage for:
  - translation selection
  - note sanitization
  - pagination behavior
  - optional API key behavior
  - safe legacy-template adoption

### Nutrition Import

- Commit references:
  - uncommitted worktree changes after `07ec8e1`

- Added screenshot-based nutrition import in the meal flow.
- Added nutrition text extraction and normalized field mapping.
- Added import review/edit confirmation UI.
- Added source image metadata and parsed-value storage on imported foods and meal items.
- Added support for dining hall nutrition modal screenshots.
- Improved screenshot import availability handling:
  - show disabled state up front when unavailable
  - disable upload button when not configured
  - show actionable `OPENAI_API_KEY` guidance

### Runtime / Docs / Validation

- Commit references:
  - uncommitted worktree changes after `07ec8e1`

- Wired screenshot import runtime configuration through `config/runtime.exs`.
- Documented screenshot import setup in `README.md`.
- Fixed stale exercise LiveView test data so the suite can pass current uniqueness rules.

## Next

### Recent Product Work Already Landed

- Commit references:
  - `5f258d5` Add AI Workout Generator feature with LiveView and tests
  - `668f3ba` Add meal plan drag/drop weekly UI with food library management
  - `6b9fe72` Fix Chart.js dependency placement for assets build
  - `c7b9222` Add Chart.js dependency for dashboard charts
  - `e0a5252` Add exercise classification fields and workout plan metadata
  - `d690952` Finalize copy consistency across Library/Exercises/Workouts pages
  - `f308069` Refactor layouts and enhance workout-plan connections
  - `bc59bc0` Add exercise library browsing, filters, and detail pages

- Added AI workout generator feature with LiveView and tests.
- Added meal-plan drag/drop weekly UI with food library management.
- Added Chart.js dashboard chart support and fixed asset build placement.
- Added exercise classification fields and workout-plan metadata.
- Added exercise library browsing, filters, and detail pages.
- Refactored layouts and improved workout-plan connections.
- Finalized copy consistency across Library, Exercises, and Workouts pages.

### Supporting Infrastructure Already Landed

- Commit references:
  - `19be7a1` Disable endpoint startup in exercise template import task

- Disabled endpoint startup in the exercise-template import task.
- Added importer persistence tests and normalization tests for exercise template imports.

## Later

### Branches / Commits Already Represented Here

- `07ec8e1` Refine WGER exercise template importer behavior
- `8614277` Improve WGER exercise template imports
- `5f258d5` Add AI Workout Generator feature with LiveView and tests
- `668f3ba` Add meal plan drag/drop weekly UI with food library management
- `6b9fe72` Fix Chart.js dependency placement for assets build
- `c7b9222` Add Chart.js dependency for dashboard charts
- `e0a5252` Add exercise classification fields and workout plan metadata
- `d690952` Finalize copy consistency across Library/Exercises/Workouts pages
- `f308069` Refactor layouts and enhance workout-plan connections
- `bc59bc0` Add exercise library browsing, filters, and detail pages
- `19be7a1` Disable endpoint startup in exercise template import task

This section is a quick index of notable recent commits already reflected in the
completed-work summaries above.
