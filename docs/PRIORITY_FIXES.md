# Priority Fixes

This file is the execution queue for the highest-priority work.

## How To Use

- Use this file for active delivery work.
- Keep items here small enough to execute and verify.
- Move completed items to `FIXED_WORK.md`.
- Move deferred or larger roadmap items to `FUTURE_TASKS.md`.
- Keep the `Branch:` line current for each active item.
- Start implementation from the listed branch and merge back to `main` only after
  verification passes.

## Status Key

- `[TODO]` not started
- `[IN-PROGRESS]` actively being worked
- `[BLOCKED]` cannot move without another fix or decision
- `[DONE]` completed and ready to move into `FIXED_WORK.md`

## Now

### [IN-PROGRESS] Preserve workout-plan origin snapshots

Branch: `feature/workout-origin-snapshots`

Dependency: explicit workout lifecycle states are complete.

Goal:

Preserve the plan and planned-exercise context that existed when a user started a
workout from a saved plan. Completed History must not change when the reusable
plan, user exercise, or source exercise template is edited or deleted later.

Scope:

- Capture one versioned origin snapshot in the same transaction that creates the
  plan-started workout.
- Preserve the originating plan identity and display metadata.
- Preserve ordered `WorkoutPlanExercise` targets: exercise, position, scheduled
  day, target sets, minimum/maximum reps, rest seconds, target kind, and notes.
- Preserve user-exercise and source-template display/muscle context needed by
  stable History and the dependent completion-time muscle aggregate.
- Keep manually created workouts snapshot-free.
- Treat the snapshot as immutable domain data. Later plan, exercise, template,
  lifecycle, and set changes must not rewrite it.
- Keep existing workouts without snapshots valid; do not infer historical
  snapshots from the legacy notes string.

Acceptance:

- The plan-start flow authorizes the plan through `current_scope`, then creates
  the workout and complete snapshot atomically.
- A snapshot failure rolls back the workout; the one-open-workout lifecycle
  invariant remains enforced.
- Plan, exercise, and template edits or deletion do not change captured content.
- Snapshot rows have no public update path and are removed only with their owning
  workout under existing retention behavior.
- Context and LiveView tests cover capture, ordering, ownership, atomic rollback,
  immutability, manual workouts, and legacy snapshot-free workouts.
- `mix precommit` passes.

Contract: `docs/design/WORKOUT_LIFECYCLE_AND_HISTORY.md`.

Out of scope for this branch:

- completion-time workout muscle aggregation
- advanced Workout History filters
- retroactive snapshot reconstruction
