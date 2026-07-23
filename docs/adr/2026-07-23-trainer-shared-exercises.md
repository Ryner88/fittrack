# ADR: Trainer-Shared Exercise Behavior

Date: 2026-07-23

## Status

Accepted

## Context

FitTrack currently has two separate exercise concepts:

- `exercise_templates` are the shared canonical exercise catalog. Admins can
  create, edit, verify, archive, and review imported metadata for these records.
- `exercises` are user-owned personal exercise records under `/my-exercises`.
  They are scoped by `user_id` and used for workout logging and planning.

Personal exercises already have an `is_private` field, but FitTrack does not yet
have trainer roles, publishing approval, moderation queues, or public ownership
pages. Letting users flip personal exercises from private to public would blur
ownership boundaries and make moderation unclear.

## Decision

Keep `/my-exercises` private. Trainer sharing should not publish user-owned
`exercises` directly.

When trainer-shared exercises are implemented, use a publishing flow that
promotes or copies trainer-created content into the shared catalog model:

- Trainers draft and edit exercises in their private library first.
- A trainer can submit an exercise for sharing only through an explicit publish
  action, not by changing a hidden form field.
- Submitted exercises become catalog candidates reviewed through admin/moderator
  tooling before becoming broadly visible.
- Approved records should be represented as `exercise_templates` or a dedicated
  trainer-submission table that creates/updates `exercise_templates`.
- Existing personal workout history must keep referencing the user's private
  `exercises`; publishing must not rewrite logged workouts.

## Permissions

- Guests can browse approved public exercise templates only.
- Signed-in users can manage only their own `/my-exercises` records.
- Trainers can submit their own exercise content for review once a trainer role
  exists.
- Admins or moderators can approve, reject, archive, or merge trainer-submitted
  exercise content.
- No user can make another user's personal exercise visible or editable.

## Moderation and Visibility

Trainer submissions should have explicit states such as `draft`, `submitted`,
`needs_changes`, `approved`, `rejected`, and `archived`. Public pages should show
only approved catalog records. Rejected or draft trainer content remains private
to the trainer and moderators.

The approved public record should carry provenance metadata, such as submitting
trainer, review status, reviewer, review notes, and source exercise/template
links. Moderation decisions should preserve auditability without exposing private
trainer drafts.

## Consequences

This keeps current private exercise behavior intact while leaving room for a
trainer publishing workflow. The cost is that trainer sharing needs a future
schema and UI design instead of reusing `is_private` as a public toggle.

Until that workflow exists, personal exercise forms and context changesets must
not accept `is_private` from user params.
