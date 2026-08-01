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

No active priority item is queued.

Recently reconciled items were moved to `FIXED_WORK.md`:

- mobile authenticated navigation blockers
- historical local migration drift
- category/tag normalization decision
- public category and muscle routes
- variation/substitution metadata
- trainer-shared exercise behavior decision

Promote the next concrete delivery item from `FUTURE_TASKS.md` when work starts
and assign its branch here before implementation.
