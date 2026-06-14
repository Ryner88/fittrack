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

- [TODO] Build admin CRUD for shared exercise templates.
  Scope:
  - add create, edit, delete, search, and review workflows for shared exercise
    templates.
  - include media status review.
  - include alias, tag, and source visibility.
  - keep destructive actions protected.

- [TODO] Complete exercise media backfill for the normalized exercise library.
  Scope:
  - run the remaining production backfill in bounded batches.
  - keep local files under `EXERCISE_MEDIA_STORAGE_ROOT`.
  - record final fetched, cached, missing, skipped, stale, and failed counts.

- [TODO] Ensure cached exercise media displays consistently on library, detail,
  and workout logging views.
  Scope:
  - verify library cards, exercise detail pages, personal exercise pages, and
    workout logging references all prefer cached media.
  - preserve safe placeholders for missing, stale, or unsupported media.

- [TODO] Add import/admin reporting for fetched, cached, missing, skipped, and
  failed media.
  Scope:
  - make media health easy to inspect from admin workflows.
  - include enough source and status detail for follow-up cleanup.

- [TODO] Add regression checks proving no active Sparky routes, assets, or
  references remain.
  Scope:
  - cover route helpers, asset manifests, app config, and deployment scripts.
  - allow clearly historical documentation references only.
