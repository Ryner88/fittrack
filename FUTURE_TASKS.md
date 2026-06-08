# Future Tasks

This file is the broader roadmap beyond the immediate execution queue.

## How To Use

- Use this file for backlog and roadmap planning.
- Items here are not expected to be worked immediately.
- Promote items into `PRIORITY_FIXES.md` when they become active.
- Summarize shipped items in `FIXED_WORK.md`.

## Now

No immediate roadmap items. Promote work from `Next` into `PRIORITY_FIXES.md` when it becomes active.

## Current Exercise Library Status

- Normalized exercise library mostly exists:
  `exercise_templates`, aliases, media, normalized muscles/equipment, template
  muscle/equipment links, variations, and substitutions are present.
- WGER importer and media pipeline mostly exist:
  template import, source ids, normalized muscle/equipment persistence, media
  reference import, media validation, and app-owned cache storage are in place.
- Exercise media backfill contract is documented in `EXERCISE_MEDIA_BACKFILL.md`.
- `EXERCISE_MEDIA_STORAGE_ROOT` remains the media storage root. Cached exercise
  media must not be stored in `priv/static`, `assets`, deploy-managed static
  directories, or DB binaries.
- Local DB readiness for exercise media is no longer the current blocker:
  `20260605144506_add_cache_fields_to_exercise_media` is applied locally and the
  required `exercise_media` cache fields exist: `cache_status`, `checked_at`,
  `content_hash`, `display_order`, `duration_seconds`, `file_size`, `local_path`,
  `source_exercise_id`, and `storage_key`.
- Non-blocking local migration history drift remains:
  `20260502000000` is recorded as applied locally but has no migration file in
  the repo. Do not reset or delete migration rows unless it starts blocking local
  migration or rollback workflows.
- Production data was not touched while resolving local DB readiness.
- Sparky cleanup status:
  no active repo references to `sparky`/`sparkyfitness` are present, and the
  local ignored `sparkyfitness/` folder is absent. Production had a stale ignored
  Sparky checkout under `/opt/fittrack/sparkyfitness`; archive/remove it outside
  the FitTrack deploy directory rather than committing anything here.

## Next

### Exercise Library / Media Follow-ups

- Resolve historical local migration drift.
  Status:
  - Non-blocking.
  - Current `exercise_media` cache migration is verified up.
  - Remaining drift is `20260502000000 ** FILE NOT FOUND **` in local migration
    history.
  Scope:
  - decide later whether to restore a no-op historical migration file, document
    it as local-only drift, or perform a local-only reset.
  - do not modify production migration history manually.

- Decide category/tag normalization.
  Status:
  - Current implementation stores `exercise_category` as a string/enum-like field.
  - Current tags use `weighted_tags` and `training_style_tags` arrays.
  Scope:
  - decide whether dedicated `exercise_categories` and `exercise_tags` tables are
    worth adding before admin CRUD expands.
  - avoid introducing tables until the query/UI benefit is clear.

- Build admin CRUD for shared exercise templates.
  Status:
  - `/admin/exercises` currently works more like an internal dashboard, metrics,
    and recent imports view.
  Scope:
  - add create/edit/delete/search/review workflows for shared exercise templates.
  - include media status review.
  - include alias/tag/source visibility.
  - keep destructive actions protected.

- Add public category and muscle routes.
  Scope:
  - add routes like `/exercises/category/:slug` and `/exercises/muscle/:slug`.
  - reuse current search/filter behavior.
  - ensure canonical slugs and SEO-friendly titles.

- Expand variation/substitution metadata.
  Status:
  - Tables exist and detail pages render relationships.
  Scope:
  - add similarity score, equipment requirements, difficulty delta, and
    substitution reason quality.
  - use this for better workout substitutions and AI workout generation.

- Define trainer-shared exercise behavior.
  Status:
  - User-created/private exercises exist under `/my-exercises`.
  Scope:
  - decide how trainers can publish/share exercises.
  - define permissions, moderation, and visibility rules.

- Add explicit workout lifecycle states.
  Scope:
  - distinguish draft, active, completed, and discarded workouts without relying on the current no-sets heuristic
  - add explicit `Finish workout` and `Discard workout` actions
  - keep Dashboard, History, and header CTAs driven by lifecycle state
  - migrate existing completed workouts and active shells safely

- Persist plan origin and workout muscle aggregation.
  Scope:
  - store the originating workout plan when a workout starts from a plan
  - snapshot planned exercise/template context so history remains stable if templates change
  - aggregate completed-session muscles from linked exercise templates and logged exercises
  - expose reliable data for filters, summaries, badges, and charts

- Add advanced Workout History filters after lifecycle, plan origin, and muscle aggregation are available.
  Scope:
  - filter by linked plan
  - filter by muscle split or trained muscle group
  - preserve the current date/calendar selection behavior as the primary date filter

- Expand normalized exercise library relationships.
  Scope:
  - add user-facing substitutions and exercise variations
  - show equipment and muscle metadata consistently across library browse, detail, and workout logging
  - support aliases/synonyms in exercise search and AI workout matching
  - add admin tools for reviewing imported template quality

- Improve exercise library search ranking.
  Scope:
  - prioritize exact name, alias, and slug matches before fuzzy matches
  - rank by target muscle and equipment filters when present
  - keep imported WGER/template results from crowding out user-created exercises when logging

- Add deployment observability after the automated deploy script lands.
  Scope:
  - persist deploy logs for each run
  - add rollback notes or an automated rollback path
  - add post-deploy smoke checks for authenticated pages, migrations, and static assets
  - document routine production maintenance commands

- Add workout streaks and achievement badges.
- Add a rest timer between sets.
- Create a post-workout summary page.
  Scope:
  - calories burned estimate
  - muscle groups worked
  - session volume, sets, reps, and duration summary
  - link back to completed workout details
- Add Google Sheets export for saved workout plans.
  Scope:
  - export button on saved plans
  - Google Sheets-compatible structure for printing or sharing
  - authentication/export permission flow if direct Google integration is used

- Remember frequently imported campus foods.
- Auto-suggest recent dining hall items.
- Favorite cafeteria meals.
- Add custom macro goals based on TDEE.
- Add water intake tracking.
- Add nutrition/workout export.
- Add automated email reminders for training and nutrition adherence.
  Scope:
  - daily workout logging reminders
  - meal plan adherence reminders
  - user opt-in/opt-out controls
  - delivery schedule preferences

- Create a gallery page for dated progress photos.
- Add side-by-side progress photo comparison.
- Add annotations for visual change tracking.

- Build a Body Metrics Tracker for:
  - weight
  - body fat %
  - waist
  - chest
  - arms
  with trend charts and progress photo integration.

- Add user preferences for goals, body metrics, and measurement units.
  Scope:
  - fitness goals
  - body metrics
  - default measurement units
  - preference-driven defaults across workout and nutrition flows

## Later

- Create dashboard progress charts.
  Scope:
  - line charts for muscle group growth over time
  - line charts for weight lifting progress over time
  - dashboard summary cards tied to the chart trends

- Create an interactive human body heat map on the dashboard.
  Goal:
  highlight muscle groups based on the past 7 days of training volume.

- Add CSV/PDF export for workout history and nutrition logs.
