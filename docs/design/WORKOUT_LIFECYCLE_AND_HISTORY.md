# Workout Lifecycle And History Design

This design covers the promoted `feature/workout-lifecycle-states` work and the
dependent history roadmap items that should stay in `FUTURE_TASKS.md` until the
lifecycle branch merges.

## Delivery Sequence

1. `feature/workout-lifecycle-states`
2. `feature/workout-origin-snapshots`
3. `feature/workout-completion-muscle-aggregation`
4. `feature/workout-history-advanced-filters`

Only the lifecycle item should be active in `PRIORITY_FIXES.md` at a time.

## Lifecycle States

Workouts should gain an explicit lifecycle state instead of deriving status from
whether sets exist.

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

## Origin Snapshots

After lifecycle states ship, starting from a saved plan should persist:

- originating `workout_plan_id`
- immutable planned exercise/template snapshot
- target sets
- target rep ranges
- rest periods
- set kind
- ordering
- notes

Snapshots keep History stable when reusable plans or shared templates are edited
later.

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
