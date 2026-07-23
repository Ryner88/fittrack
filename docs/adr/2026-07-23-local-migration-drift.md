# ADR: Historical Local Migration Drift

Date: 2026-07-23

## Status

Accepted

## Context

The local development database recorded migration `20260502000000` as applied,
but no file with that version exists in `priv/repo/migrations`.

Git history shows that `20260502000000_create_foods_and_update_meal_items.exs`
was renamed to `20260418160000_create_foods_and_update_meal_items.exs` to run
before dependent nutrition migrations. The local database had both migration
versions recorded, while the repository correctly has only the renamed file.

## Decision

Treat this as local migration metadata drift and repair only the local
development database:

- Remove the stale local `schema_migrations` row for `20260502000000`.
- Do not restore a no-op historical migration file.
- Do not edit, rename, or reorder tracked migration files.
- Do not change production migration history unless a real production migration
  workflow later proves it has the same drift and requires an explicit,
  environment-specific repair.

## Consequences

Local `mix ecto.migrations` now reflects the repository migration chain without
`FILE NOT FOUND`. Rollback and migrate operations can target tracked migrations
predictably.

Production history remains untouched. If another environment reports the same
stale version, handle it as an environment-specific metadata repair after
confirming that both `20260418160000` and `20260502000000` represent the same
renamed migration.
