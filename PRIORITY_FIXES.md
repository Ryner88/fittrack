# Priority Fixes

This file is the execution queue for the highest-priority work.

## How To Use

- Use this file for active delivery work.
- Keep items here small enough to execute and verify.
- Move completed items to `FIXED_WORK.md`.
- Move deferred or larger roadmap items to `FUTURE_TASKS.md`.

## Status Key

- `[todo]` not started
- `[in-progress]` actively being worked
- `[blocked]` cannot move without another fix or decision
- `[done]` completed and ready to move into `FIXED_WORK.md`

## Now

- `[todo]` Clarify the Plans page as reusable workout templates.
  Done when:
  - page header is `Workout Plans`
  - supporting copy is `Create and manage reusable workout templates for consistent training.`
  - page-level actions are `AI Generator` and `Create plan`
  - plan cards/rows show plan name, goal/type, days per week, exercise count, and last used when available
  - plan row actions use `Start from plan`, `Edit`, and `Duplicate`
  - `Repeat` is not used for plans
  - `Browse plans` only appears if browsing is distinct from the current Plans page
  - targeted tests pass
  - `mix precommit` is green

- `[todo]` Clarify active workout state across the app.
  Done when:
  - no active workout state shows primary `Start workout` and secondary `Browse plans`
  - active workout state shows contextual `Resume workout`
  - optional actions are intentionally implemented or deferred: `Finish workout`, `Discard workout`
  - active-session CTAs are consistent across Dashboard, History, and global/header placement where present
  - active sessions stay separate from completed History records
  - targeted tests pass
  - `mix precommit` is green

- `[todo]` Refine workout information architecture and header actions.
  Done when:
  - primary navigation remains Dashboard, Nutrition, Exercises, Plans, History
  - `Start workout` is a primary CTA rather than a main nav item
  - optional quick-start dropdown is implemented or intentionally deferred: `Start empty workout`, `Browse plans`, `Resume workout`
  - duplicate account/header actions are consolidated into one profile area
  - settings/logout/theme are grouped into one profile dropdown or deliberately deferred
  - duplicate email display is removed
  - targeted tests pass
  - `mix precommit` is green
