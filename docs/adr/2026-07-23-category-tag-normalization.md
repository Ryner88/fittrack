# ADR: Category and Tag Normalization

Date: 2026-07-23

## Status

Accepted

## Context

FitTrack currently stores exercise classification in two lightweight forms:

- `exercise_category` is a string field on exercises and exercise templates.
- `weighted_tags` and `training_style_tags` are string arrays on exercise templates.

The normalized exercise library already has dedicated tables for entities that
need relationships, source metadata, or admin curation: muscles, equipment,
aliases, media, sources, variations, and substitutions. Categories and tags are
used today as filters, badges, search terms, and importer-derived metadata, not
as independently managed records.

Dedicated `exercise_categories`, `exercise_tags`, and join tables would become
useful if FitTrack needs taxonomy records with their own lifecycle. Examples
include curated descriptions, aliases/synonyms, public landing pages, hierarchy,
manual ordering, locale-specific labels, merge/split workflows, visibility
controls, or analytics keyed to stable tag IDs.

The current product workflows do not require those capabilities yet. Library and
admin screens can filter by category and tag token, render readable labels, and
search through existing columns. The existing indexes also match the present
query shape: B-tree indexes for category-like fields and GIN indexes for tag
arrays.

## Decision

Keep categories and tags as normalized string values for now:

- Continue using `exercise_category` for the single primary category.
- Continue using `weighted_tags` and `training_style_tags` arrays for tag-like
  metadata.
- Normalize category and tag values at write/import boundaries by trimming,
  downcasing, and using stable underscore-separated tokens.
- Keep public labels as presentation concerns derived from normalized tokens.
- Do not add `exercise_categories`, `exercise_tags`, or join tables until there
  is a concrete need for tag ownership, synonyms, translations, rich metadata,
  ordering rules, or cross-record governance.

## Query and UI Benefits Considered

Dedicated tables would provide these benefits:

- Stable IDs for public category/tag pages and analytics.
- Curated display metadata such as descriptions, canonical labels, sort order,
  icons, and SEO copy.
- Alias and synonym handling without baking every variant into importer code.
- Admin merge/split workflows when imported sources disagree on taxonomy.
- Referential integrity for tags once the product treats them as first-class
  records.

Those benefits are not yet worth the schema cost because the active UI only
needs filtering, display labels, and search expansion. Those needs are satisfied
by normalized tokens, current indexes, and presentation helpers.

## Migration Cost

Adding dedicated taxonomy tables later would require a forward migration that:

- Creates category/tag tables and template join tables.
- Backfills records from `exercise_category`, `weighted_tags`, and
  `training_style_tags`.
- Preserves existing filters while moving reads to joins or compatibility views.
- Updates importer, admin forms, public filters, fixtures, and tests.
- Defines duplicate handling for equivalent imported tags.

That is a reasonable migration when taxonomy records become product objects. It
is unnecessary churn while tags remain lightweight metadata.

## Consequences

This keeps the schema simple and avoids adding relational tables before the UI
or query model needs them. Existing GIN indexes and array filters remain
appropriate for the current library/admin workflows.

The tradeoff is that categories and tags remain application-governed tokens
rather than database-governed entities. If admin CRUD expands to require
descriptions, aliases, merge workflows, per-tag visibility, or analytics by tag
identity, revisit this decision and introduce dedicated tables through a new
forward migration.
