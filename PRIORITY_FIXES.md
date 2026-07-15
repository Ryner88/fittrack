# Priority Fixes

This file is the execution queue for the highest-priority work.

## How To Use

- Use this file for active delivery work.
- Keep items here small enough to execute and verify.
- Move completed items to `FIXED_WORK.md`.
- Move deferred or larger roadmap items to `FUTURE_TASKS.md`.

## Status Key

- `[TODO]` not started
- `[IN-PROGRESS]` actively being worked
- `[BLOCKED]` cannot move without another fix or decision
- `[DONE]` completed and ready to move into `FIXED_WORK.md`

## Now

- [TODO] Resolve historical local migration drift.
  Branch: `task/resolve-migration-drift`
  Scope:
  - decide whether to restore a no-op historical migration file, document it as
    local-only drift, or perform a local-only reset.
  - keep production migration history untouched unless a real production
    migration workflow requires it.
  - verify local migration and rollback workflows still behave predictably.

- [TODO] Decide category/tag normalization.
  Branch: `task/category-tag-normalization`
  Scope:
  - decide whether dedicated `exercise_categories` and `exercise_tags` tables are
    worth adding before further taxonomy expansion.
  - document query/UI benefits and migration cost before adding schema.
  - avoid introducing tables until the product benefit is clear.

- [TODO] Add public category and muscle routes.
  Branch: `feature/public-exercise-taxonomy-routes`
  Scope:
  - add routes like `/exercises/category/:slug` and `/exercises/muscle/:slug`.
  - reuse current exercise library search/filter behavior.
  - ensure canonical slugs, SEO-friendly titles, and guest/current-user route
    scope behavior remain correct.

- [TODO] Expand variation/substitution metadata.
  Branch: `feature/exercise-relationship-metadata`
  Scope:
  - add similarity score, equipment requirements, difficulty delta, and
    substitution reason quality.
  - use the metadata for better workout substitutions and AI workout generation.
  - surface the metadata consistently in admin review and exercise detail flows.

- [TODO] Define trainer-shared exercise behavior.
  Branch: `feature/trainer-shared-exercises`
  Scope:
  - decide how trainers can publish/share exercises.
  - define permissions, moderation, and visibility rules.
  - keep private `/my-exercises` behavior intact while designing shared
    trainer-created exercise flows.
