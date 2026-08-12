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

### UML Design

The source PlantUML file is `docs/diagrams/ARCHITECTURE.puml`. The active
origin-snapshot implementation should be designed against these named diagrams:

- `Fittrack_Workout_Origin_Snapshot_Domain`: class model for the immutable
  workout-level origin, ordered exercise entries, and copied normalized muscle
  rows.
- `Fittrack_Workout_Origin_Snapshot_Transaction`: sequence diagram for
  `Training.create_workout_from_plan/2`, including transaction-scoped
  authorization and preloading, rollback behavior, the no-template fallback
  path, and the manual/legacy workout exclusions.

Design decisions represented by the UML:

- use one workout-level origin row and many ordered exercise-entry rows instead
  of adding snapshot fields directly to `workout_sessions`
- use `Workout 1 -> 0..1 WorkoutOriginSnapshot`,
  `WorkoutOriginSnapshot 1 -> many WorkoutOriginExerciseSnapshot`, and
  `WorkoutOriginExerciseSnapshot 1 -> many WorkoutOriginMuscleSnapshot`
- copy historical scalar/display data from `WorkoutPlan`,
  `WorkoutPlanExercise`, `Exercise`, `ExerciseTemplate`, and normalized template
  muscle rows
- keep `source_*_id` values as historical references, not as the source of
  History display truth
- make snapshot capture part of the same transaction as the active workout
  creation, including source plan authorization and loading, so partial
  plan-start workouts cannot survive failed capture and plan edits cannot land
  between preload and capture
- allow snapshot absence for manual and legacy workouts
- allow user-created exercises without source templates to produce exercise
  snapshots from fallback exercise muscle strings and zero normalized-muscle
  snapshot rows

### Creation Boundary

`Training.create_workout_from_plan/2` is the only creation boundary for a
plan-origin snapshot. It must:

1. open a `Repo.transaction/1`
2. authorize and load the user-owned plan through `current_scope` inside the
   transaction
3. preload ordered plan exercises, user exercises, source templates, and
   normalized template muscles inside the transaction
4. create the active workout and its complete snapshot inside the same
   transaction
5. roll back the workout if authorization, loading, or any snapshot insert fails

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

When an exercise has no source template, the exercise snapshot is still valid.
It should keep copied user-exercise muscle strings for fallback display and
future aggregation, and it should have zero normalized-muscle snapshot rows.

Do not snapshot media URLs, cache paths, or timestamps from mutable source rows.
They are not required to reconstruct the planned workout or to support the
dependent muscle aggregate.

### Database Constraints

Persist the immutable snapshot with constraints that enforce the contract:

- one unique snapshot per owning workout
- owning workout foreign key cascades deletion to the snapshot, exercise
  snapshots, and muscle snapshots
- copied plan, plan-exercise, user-exercise, source-template, and normalized
  muscle IDs are stored as scalar historical values without live foreign keys
- valid `schema_version` constraint for supported snapshot versions, starting
  with `1`
- deterministic exercise ordering by snapshot, `position`, then copied
  source plan-exercise id
- deterministic muscle ordering by exercise snapshot, `role`, `position`, then
  copied source muscle id

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
