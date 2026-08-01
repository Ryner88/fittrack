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

- [IN-PROGRESS] Add explicit workout lifecycle states.
  Branch: `feature/workout-lifecycle-states`
  Scope:
  - distinguish draft, active, completed, and discarded workouts without relying
    on the current no-sets heuristic
  - add explicit `Finish workout` and `Discard workout` actions
  - keep Dashboard, History, and header CTAs driven by lifecycle state
  - migrate existing completed workouts and active shells safely
  - document and test lifecycle transitions, timestamp semantics, active-workout
    invariants, and deterministic migration/backfill rules before shipping

Recently reconciled items were moved to `FIXED_WORK.md`:

- mobile authenticated navigation blockers
- historical local migration drift
- category/tag normalization decision
- public category and muscle routes
- variation/substitution metadata
- trainer-shared exercise behavior decision
