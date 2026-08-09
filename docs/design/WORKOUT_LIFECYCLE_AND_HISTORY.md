# Workout Lifecycle And History Design

This design records the shipped workout lifecycle contract and the dependency
sequence for stable workout History. `feature/workout-origin-snapshots` is the
current active delivery item.

## Delivery Sequence

1. `feature/workout-lifecycle-states` — complete
2. `feature/workout-origin-snapshots` — active
3. `feature/workout-completion-muscle-aggregation`
4. `feature/workout-history-advanced-filters`

Only the first incomplete item should be active in `PRIORITY_FIXES.md` at a
time.

## Lifecycle States

Workouts use an explicit lifecycle state instead of deriving status from whether
sets exist.

Allowed states:

- `draft`: a created workout shell that is not actively being logged
- `active`: the user's current open logging session
- `completed`: a finished workout included in History, summaries, streaks, and
  future charts
- `discarded`: an intentionally abandoned workout excluded from active, History,
  summaries, streaks, and charts

Allowed transitions:

- `draft -> active`
- `active -> completed`
- `draft -> discarded`
- `active -> discarded`

`draft -> active` happens through an explicit Start action or by logging the
first set. Completed and discarded workouts are terminal for this first delivery;
reopening should require a later explicit design.

Discard is a soft state, not physical deletion. Existing logged data remains
owned by the user and auditable, but discarded workouts are hidden from normal
training surfaces.

## Timestamp Semantics

- `started_at`: the time a workout becomes active. Existing active sessions keep
  their current `started_at`.
- `completed_at`: set when `active -> completed` succeeds.
- `discarded_at`: set when `draft/active -> discarded` succeeds.
- `inserted_at` and `updated_at`: remain Ecto persistence metadata only.

`Finish workout` and `Discard workout` operations must be idempotent for the
owning user. Repeated finish/discard requests should not create duplicate state
changes or expose another user's workout.

## Active-Workout Invariant

FitTrack should enforce one open workout per user across `draft` and `active`.
Prefer a database-level partial unique index for states in `draft` and `active`,
plus context-level checks that return deterministic errors when a user already
has an open workout.

Dashboard, History, and shared layout CTAs should query by lifecycle state:

- Resume CTA: newest `active` workout for the current user
- Start CTA: no `active` workout exists
- History: `completed` workouts only

All LiveViews must use the existing authenticated route placement and pass
`current_scope` into Training context functions. Templates should derive the user
from `@current_scope.user`, never `@current_user`.

## Migration And Backfill Rules

The lifecycle migration must deterministically classify existing
`workout_sessions` before any UI starts reading the new state.

Proposed local and production-safe backfill:

- Workouts containing one or more sets become `completed`.
- `completed_at` is derived from the latest set `inserted_at`, falling back to
  the workout `updated_at`, then `started_at`.
- For each user, the newest empty workout shell becomes `draft`.
- Older empty workout shells become `discarded`.
- `discarded_at` for backfilled discarded shells uses `updated_at`, falling back
  to `started_at`.

The migration should not delete sessions. Rollback behavior should remove only
the lifecycle columns/indexes introduced by the migration.

## Web And Mobile API Contract

Even though the current Phoenix app is the primary surface, lifecycle behavior
should be serialization-ready for mobile/API clients:

- expose lifecycle state and timestamps in any workout JSON representation
- allow mutation through explicit finish/discard operations, not generic user
  params
- reject unauthorized transitions by checking `current_scope.user`
- keep discarded workouts out of default list endpoints unless explicitly
  requested by a future admin/audit flow

## Origin Snapshot Contract

### Creation Boundary

`Training.create_workout_from_plan/2` is the only creation boundary for a
plan-origin snapshot. It must:

1. authorize and load the user-owned plan through `current_scope`
2. preload ordered plan exercises, user exercises, source templates, and
   normalized template muscles
3. create the active workout and its complete snapshot in one
   `Repo.transaction/1`
4. roll back the workout if any snapshot record is invalid or cannot be inserted

The capture time is the instant the plan-started workout is created. A manual
workout has no origin snapshot. Existing workouts also remain snapshot-free:
the legacy `"Started from plan: ..."` notes value is display text and is not a
safe source for reconstruction.

### Persisted Shape

Use one immutable workout-level origin record and ordered immutable exercise
entries. The exact Ecto module names may follow project conventions, but the
version-1 data contract is:

Workout-level origin:

- unique owning `workout_session_id`
- `source_workout_plan_id` copied as a historical scalar, not as the sole source
  of truth for a live association
- `schema_version: 1`
- `captured_at`
- copied plan context:
  - name and description
  - legacy goal
  - primary style and secondary style tags
  - primary, secondary, tertiary, and additional goals
  - training styles and training split
  - difficulty and estimated duration

Each ordered exercise entry:

- source `workout_plan_exercise_id`, `exercise_id`, and optional
  `source_template_id` copied as historical scalars
- `position` and `scheduled_day`
- `target_sets`, `target_reps_min`, `target_reps_max`, `rest_seconds`,
  `target_kind`, and plan-exercise notes
- copied user-exercise context: name, slug, primary muscle, secondary muscles,
  equipment, movement pattern, exercise category, and training-style tags
- copied source-template context when present: name, canonical slug, primary
  muscle, secondary muscles, equipment, movement pattern, exercise category,
  and training-style tags
- copied normalized template muscles ordered deterministically, including
  historical muscle id, name, normalized name, region, role, and position

Do not snapshot media URLs, cache paths, or timestamps from mutable source rows.
They are not required to reconstruct the planned workout or to support the
dependent muscle aggregate.

### Immutability And Deletion

Snapshot content is append-once domain data:

- expose a create path only; do not add public update or delete context functions
- do not include snapshot fields in generic workout changesets
- lifecycle transitions, set logging, and completion must never rewrite a
  snapshot
- edits to or deletion of a plan, plan exercise, user exercise, source template,
  or normalized muscle must not cascade into or null captured scalar/context
  values
- snapshot rows may be removed only when their owning workout is physically
  deleted under the existing user/workout retention behavior

A live plan association may be added for navigation, but it is optional and must
not replace `source_workout_plan_id` or copied plan context. History must still
render the captured plan name after the live plan disappears.

### Read And Dependency Contract

History reads use copied snapshot values, never current plan/template values.
The later linked-plan filter may use `source_workout_plan_id`; completion-time
muscle aggregation may use the copied normalized template muscles and fall back
to copied user-exercise muscle strings.

Plan-exercise entries must be serialized in deterministic `position`, then
source-id order. Snapshot absence is a supported state for manual and legacy
workouts and must not prevent listing, completing, discarding, or viewing them.

## Completion Muscle Aggregation

After origin snapshots ship, completion should persist trained muscle aggregates
from:

- normalized linked exercise-template muscles
- planned template snapshot data
- fallback string fields on user-owned exercises when no source template exists

The aggregate should be written at completion time so History filters and future
charts do not recompute mutable template relationships for every request.

## Advanced History Filters

Advanced filters depend on lifecycle states, origin snapshots, and muscle
aggregation.

Filter behavior:

- only query `completed` workouts
- date/calendar selection remains primary
- linked plan and muscle filters refine the selected date/range
- query functions receive `current_scope` and filter by `current_scope.user`
