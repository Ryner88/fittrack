# Fixed Work

This file is a release-notes style summary of work that has already been completed
or materially addressed on the recent branches.

## How To Use

- Use this file as the completed-work log.
- Keep entries outcome-focused, not task-list focused.
- When possible, include commit references for traceability.
- Do not keep open work here; open work belongs in `PRIORITY_FIXES.md` or `FUTURE_TASKS.md`.

## Now

### Non-Interactive Production Restart

- Commit references:
  - `81c5cfb` Restart production release without sudo in deploy script

- Made production service restarts non-interactive for `deploy.sh`.
- Updated `deploy.sh` to restart with `_build/prod/rel/fittrack/bin/fittrack restart`.
- Removed the dependency on interactive `sudo systemctl restart`.
- Kept service verification with non-sudo `systemctl is-active fittrack`.
- Added a local endpoint wait against `http://127.0.0.1:${PORT}/`.
- Confirmed no passwordless sudo rule was added.
- Verified:
  - `bash -n deploy.sh` passed
  - `mix precommit` passed with 229 tests and 0 failures
  - commit was pushed to `main`

### Workout Logging Form References

- Commit references:
  - `a0cc65d` Merge pull request #14 from Ryner88/workout-logging-form-video-links

- Added a compact form-reference area to the active workout set logging form.
- Selected linked exercises now surface the best available media reference:
  - cached video media through `/exercise-media/:id`
  - safe external video URLs for valid remote-only video media
  - cached image media as a fallback form reference
- External video references open in a new tab with `target="_blank"` and `rel="noopener noreferrer"`.
- No-media and stale/broken-media cases show a subtle `No form reference available` fallback.
- Custom exercises without a linked source template render safely without crashing.
- Set entry inputs remain unchanged and available for reps, weight, set type, rest, and notes.
- Added LiveView coverage for cached video, external video, no usable media, and custom/no-linked-template cases.
- Status: fixed and verified in production.
- Production deployment and verification:
  - merged and deployed workout logging form media references
  - production updated from `32083db` to `a0cc65d`
  - verified checkout was clean before and after deploy
  - `./deploy.sh` completed git pull, environment load, dependency fetch, compile, migrations, asset deploy, and release creation
  - restarted release successfully with `_build/prod/rel/fittrack/bin/fittrack restart`
  - verified public site recovered from the restart window and returned `HTTP/2 200`
  - created temporary production verification data: temp user, linked exercise, workout, and set
  - verified `/workouts/2?exercise_id=3` returned 200
  - verified workout logging rendered `#workout-set-form`, exercise select, weight input, `Form reference`, and cached media link `href="/exercise-media/4"`
  - verified saved set rendered after save
  - cleaned up temporary verification data: `temp_users: 0`, `temp_workouts: 0`, `temp_sets: 0`
  - confirmed service is active using non-sudo `systemctl status`
  - confirmed non-sudo journal logs showed endpoint restart and verified workout requests returned 200

### Exercise Media Backfill

- Commit references:
  - `32083db` Add cached exercise media backfill

- Added a cached exercise media subsystem for the normalized exercise library.
- Extended `exercise_media` with cache/audit fields for source exercise IDs, local paths, file size, checked time, failure reason, display order, and duration.
- Added WGER media pagination and normalization for image/video records.
- Added media validation for missing URLs, invalid schemes, stale 404/410 URLs, unsupported content types, zero-byte files, and oversized files.
- Added app-owned media caching with checksum, content type, file size, and local path metadata.
- Added `mix fittrack.backfill_exercise_media` with dry-run, limit, exercise-id, force-check, skip-download, media-type, and concurrency option parsing.
- Added backfill reporting for fetched, cached, already cached, missing, skipped, stale, failed, and exercises-with-no-media counts.
- Kept repeated runs idempotent and prevented importer/backfill refreshes from downgrading cached media back to remote-only.
- Replaced live WGER image proxying with cached media serving:
  - `GET /exercise-media/:id`
  - compatibility primary-image route at `GET /exercise-template-images/:id`
- Updated exercise library cards, exercise detail pages, personal exercise pages, and workout logging shortcuts/search rows to use cached media or placeholders.
- Added admin media status reporting for cached, missing URL, skipped, stale, and failed records.
- Added regression coverage for WGER media fetching, validation, caching, idempotency, task reporting, cached controller responses, and LiveView rendering.
- Verified `mix precommit` passes.

### Production Checkout Drift Cleanup

- Commit references:
  - production cleanup completed outside the repo
  - uncommitted documentation update

- Resolved production checkout drift before the next deploy.
- Confirmed `/opt/fittrack` working tree was clean.
- Backed up old server stashes outside the repo:
  - `/home/nova/fittrack-stash-backups/stash-0-codex-before-exercise-media-backfill-deploy.patch`
  - `/home/nova/fittrack-stash-backups/stash-1-server-local-tracked-changes-before-pull.patch`
- Dropped both old Git stashes.
- Confirmed `git stash list` is empty.
- Confirmed `git status --short` is clean.
- Result:
  - production checkout is clean for future deploys
  - the dirty-working-tree guard in `deploy.sh` should now allow clean deploys and block accidental server-local edits

### Production Deployment Validation

- Commit references:
  - `17e1176` feat: add automated deployment script
  - uncommitted deployment hardening follow-up

- Validated `deploy.sh` on the target production server.
- Confirmed the deployment flow completed successfully:
  - pulled from `main`
  - loaded environment configuration
  - fetched dependencies
  - compiled Elixir code
  - ran database migrations
  - deployed assets
  - created the production release
  - restarted `fittrack.service`
  - verified the service was active after restart
- Verified migration safety:
  - deploy-script migration verification passed
  - two manual migration re-runs returned `Migrations already up`
  - duplicate exercise slug validation returned `0 rows`
- Confirmed the external health check passed:
  - `https://fitness.nextgenbytes.me/` returned `HTTP/2 200`
  - homepage HTML loaded
  - post-deploy logs showed `GET /` and `HEAD /` returning `200`
- Recorded production caveats:
  - `/opt/fittrack` was not a clean checkout during validation
  - production uses `DATABASE_URL`, not `DB_PASSWORD`
  - `DATABASE_URL` uses the Ecto URL format, so direct `psql` checks need either URL parsing or `sudo -u postgres psql -d fittrack_prod`
  - deploy user `nova` needs sudo permission/password for `systemctl restart fittrack`
- Hardened the repo after validation:
  - `deploy.sh` now refuses to pull/deploy from a dirty working tree
  - `deploy.log` is ignored by git

### AI Workout Generation, 1RM Calculator, And Set Types

- Commit references:
  - uncommitted worktree changes

- Expanded AI workout generation with a session duration input.
- Wired generated plans to persist estimated duration and duration-aware exercise volume.
- Added generated plan target set types based on goal context, including top sets, working sets, supersets, and AMRAP sets.
- Added linked source support to the AI generator:
  - users can paste a workout video, article, or training guide URL
  - source content is fetched with `Req` through a configurable client
  - readable page text is summarized into the generated plan notes
  - when `OPENAI_API_KEY` is configured, linked content is parsed into structured FitTrack workout JSON
  - parsed source exercises are matched against WGER-backed templates and converted into user exercises before draft review
  - detected source cues can guide set types such as supersets, circuits, drop sets, AMRAP sets, timed sets, warm-up sets, failure sets, and rest-pause sets
- Changed the AI generator from save-immediately to draft review:
  - generated plans are shown in a review panel first
  - users can edit plan name, notes, duration, sets, reps, rest, exercise notes, and set types before saving
  - save persists the reviewed draft as the reusable workout plan
- Added planned-exercise set type persistence with a `target_kind` column.
- Added set type selection to workout plan editing and displayed target set type on plan details.
- Expanded logged set types to include myo-reps, feeder sets, straight sets, warm-up sets, working sets, drop sets, supersets, circuits, AMRAP sets, timed sets, rest-pause sets, top sets, and back-off sets.
- Added an authenticated `/one-rep-max` LiveView calculator with:
  - Epley estimated 1RM
  - percentage loading table
  - optional bodyweight-relative strength standard
- Kept the new 1RM route in the existing authenticated router placement:
  - `scope "/", FittrackWeb`
  - `pipe_through [:browser, :require_authenticated_user]`
  - `live_session :require_authenticated_user`
  This is required because the tool is part of the logged-in training workspace and receives `current_scope` through the authenticated LiveView session.
- Added regression coverage for generator duration, source-guided drafts, generated set types, advanced logged set types, reviewed draft saving, and the 1RM calculator.
- Verified `mix precommit` passes.

### Workout Command Bar

- Commit references:
  - uncommitted worktree changes

- Added an authenticated command bar to the shared app layout.
- Added a header trigger with `Ctrl K`/`Cmd K` keyboard support.
- Included context-aware workout commands:
  - no active workout: `Start empty workout`, `Start from plan`
  - active workout: `Resume workout`, `Log set`
- Included quick navigation commands:
  - Dashboard
  - Nutrition
  - Exercises
  - Plans
  - History
- Included creation shortcuts:
  - Log meal
  - Build weekly meal plan
  - AI workout generator
- Added client-side filtering, arrow-key movement, escape-to-close, backdrop close, and empty search state in the existing `assets/js/app.js` bundle.
- Added regression coverage for inactive and active workout command sets.

### Nutrition Core, Performed Workout Logging, And Import Polish

- Commit references:
  - uncommitted worktree changes

- Completed core nutrition flow coverage:
  - meal logging supports create, edit/update, view/list, and delete paths
  - meal plans support create, edit/update, view/list, duplicate, and delete paths
  - the nutrition dashboard already summarizes today's intake, weekly plan context, and recent meals
  - nutrition routes remain in the existing authenticated route placement:
    - `scope "/", FittrackWeb`
    - `pipe_through [:browser, :require_authenticated_user]`
    - `live_session :require_authenticated_user`
    This is required because nutrition data is user-scoped through `current_scope`.
- Clarified workout logging around performed data:
  - `Start from plan` now starts an active workout shell instead of pre-creating performed sets
  - workout set fields now label logged values as `Performed weight` and `Performed reps`
  - workout detail shows performed set and volume summaries separately from template source context
  - dashboard workout counts and month markers now ignore active workouts without performed sets
  - completed History remains based on workouts with performed sets
- Finished nutrition import polish:
  - barcode, dining URL, and screenshot imports all feed into the review/confirmation panel before saving
  - added persistent import status states for ready-to-review, empty, and failure outcomes
  - screenshot unavailable state gives `OPENAI_API_KEY` setup guidance
  - source image metadata and parsed field mappings remain persisted through food and meal item save paths
- Added regression coverage for:
  - meal and meal-plan CRUD context behavior
  - completed-only workout counts and calendar markers
  - `Start from plan` remaining active until performed sets are logged
  - barcode success, empty, and failure import states
  - unsupported dining URL import state
  - screenshot review state

### Workout Plans, Active Workout CTAs, And Header IA

- Commit references:
  - uncommitted worktree changes

- Clarified Workout Plans as reusable training templates:
  - header remains `Workout Plans`
  - supporting copy is `Create and manage reusable workout templates for consistent training.`
  - page actions are `AI Generator` and `Create plan`
  - plan cards show plan name, goal/type, days per week, and exercise count
  - plan actions use `Start from plan`, `Edit`, and `Duplicate`
  - `Repeat` and same-page `Browse plans` actions are not used on Plans
- Standardized active workout CTAs:
  - no active workout: `Start workout` plus `Browse plans` on Dashboard and History
  - active workout: `Resume workout` on Dashboard, History, and the app header
  - active sessions remain excluded from completed History records
- Refined header IA:
  - main navigation remains Dashboard, Nutrition, Exercises, Plans, History
  - `Start workout` is a primary header CTA instead of a main nav item
  - account, settings, logout, and theme controls are grouped in one profile menu
  - the duplicate root-level account strip was removed
- Kept the affected LiveViews in the existing authenticated router placement:
  - `scope "/", FittrackWeb`
  - `pipe_through [:browser, :require_authenticated_user]`
  - `live_session :require_authenticated_user`
  This is required because these pages read user-owned workout data through `current_scope`.
- Added regression coverage for:
  - reusable-template copy, metadata, and actions on Plans
  - Dashboard Start/Browse vs Resume states
  - header Start vs Resume states
  - consolidated profile menu links
- Verified `mix precommit` passes.
- Deferred explicit `Finish workout`, `Discard workout`, and quick-start dropdown behavior until workouts have an explicit lifecycle state beyond the current no-sets active heuristic.

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
