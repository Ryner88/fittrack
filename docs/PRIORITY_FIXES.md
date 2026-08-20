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

### [IN-PROGRESS] Persist completed-workout muscle aggregation

Branch: `feature/workout-completion-muscle-aggregation`

Dependency: `feature/workout-origin-snapshots` is complete and this branch is
stacked on top of it.

Goal:

Persist per-workout muscle summaries when a workout becomes completed so
History, filters, badges, and charts can use stable completed-session muscle
data instead of recomputing from mutable exercise sources.

Scope:

- Add persisted per-workout muscle summary rows with a stable token, display
  name, role, sets, reps, and volume.
- Rebuild summaries transactionally when an active workout is completed.
- Include quick-log workouts in the same aggregate path.
- Prefer immutable origin-snapshot muscles for plan-started workouts.
- Fall back to live normalized template muscles, then user-exercise muscle
  strings when no origin snapshot muscle data exists.
- Keep repeated completion calls idempotent.
- Preserve completed summary rows if source templates or normalized source rows
  are deleted later.
- Cascade summaries with their owning workout.

Acceptance:

- Completion and quick-log aggregation happen inside their existing write
  transactions.
- Context reads are scoped by workout ownership.
- Aggregates include normalized/live muscles, origin snapshot muscles, string
  fallbacks, multi-muscle secondary work, empty completed workouts, and
  idempotent recompletion behavior.
- Database constraints enforce ownership link, role values, non-negative metrics,
  uniqueness, and cascade deletion.
- Focused regression tests cover all acceptance cases.
- `mix precommit` passes.

Contract: `docs/design/WORKOUT_LIFECYCLE_AND_HISTORY.md`.

Out of scope for this branch:

- advanced Workout History filters
- retroactive snapshot reconstruction
