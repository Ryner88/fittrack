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

### [TODO] Add advanced Workout History filters

Branch: `feature/workout-history-advanced-filters`

Dependencies: workout lifecycle states, origin snapshots, and completed-workout
muscle aggregation are complete on `main`.

Goal:

Let users refine completed Workout History by linked plan and trained muscle
group while preserving the existing date/calendar selection as the primary
filter.

Scope:

- Add linked-plan filtering from captured workout origin data.
- Add trained-muscle filtering from persisted workout muscle summaries.
- Keep the calendar date as the primary boundary. Plan and muscle filters only
  refine the selected-day workout list.
- Leave calendar counts, monthly statistics, and global summary statistics
  unfiltered.
- Preserve ownership-scoped context reads by passing `current_scope` and
  filtering through `current_scope.user`.
- Keep manual workouts, legacy workouts without snapshots, and workouts without
  muscle summaries visible when no matching advanced filter is selected.
- Add stable DOM IDs for new filter controls and result states.
- Keep advanced filters as single-select LiveView state, not URL parameters.
- Preserve existing UTC calendar-date semantics for `started_at`.

Filter semantics:

- Selected-day results use `date AND linked_plan_id AND muscle_token`. Blank
  plan or muscle values mean "all", not `NULL`.
- The plan filter uses captured `source_workout_plan_id`, not the live plan
  association. Options come from the user's completed workout origin snapshots.
- Each plan ID appears once. Its label is the most recently captured
  `plan_name`.
- A selected plan ID matches all historical snapshots for that ID, including
  workouts captured under older plan names. Deleted plans remain selectable
  because the options do not read from the live plan table.
- Manual and legacy workouts without origin snapshots do not match a selected
  plan.
- The muscle filter uses persisted `muscle_token`, not display name. A workout
  matches when any summary row has the selected token, whether the role is
  primary or secondary.
- Duplicate summary rows for the same token must not duplicate the workout.
  Muscle labels come from persisted summaries. Workouts without summaries do not
  match a selected muscle.
- Invalid or stale plan and muscle values fall back to "all".
- Month navigation clears the selected date and selected-day results, but keeps
  the advanced-filter selections.
- Clearing either advanced filter reloads selected-day results immediately when
  a date is selected.

Acceptance:

- Filter queries only return `completed` workouts owned by the current user.
- Plan filters continue working after the source plan is renamed or deleted.
- Muscle filters match persisted primary and secondary muscle summary rows.
- Combining date, linked-plan, and muscle filters returns the expected
  intersection without changing the calendar UX.
- Empty filtered states are explicit and covered by LiveView tests using stable
  selectors.
- Selected-day filtering uses stable DOM IDs:
  `#history-plan-filter`, `#history-muscle-filter`, `#history-clear-filters`,
  `#history-no-date-selected`, and `#history-no-filtered-results`.
- The filtered-empty state says no workouts match the selected filters. It is
  distinct from the no-completed-workouts-on-date state.
- Completed matching workouts are returned.
- Active, draft, and discarded matching workouts are excluded.
- Another user's matching workouts and filter options are excluded.
- Plan filtering works after the source plan is renamed.
- Plan filtering works after the source plan is deleted.
- Manual and legacy snapshot-free workouts remain visible without a plan filter.
- Primary-muscle and secondary-muscle matches work.
- The same muscle in multiple roles does not duplicate a workout.
- Date, plan, and muscle filters use AND semantics.
- Clearing plan or muscle restores selected-day results.
- Month navigation clears the selected date/results and preserves selected
  advanced filters.
- Existing calendar counts and summary statistics stay unfiltered.
- Context APIs use scoped option-list queries and date-range options:
  `Training.list_history_plan_options(scope)`,
  `Training.list_history_muscle_options(scope)`, and
  `Training.list_completed_workouts_in_date_range(scope, start_date, end_date,
  plan_id: plan_id, muscle_token: muscle_token)`.
- Completed workout ordering is deterministic: `started_at DESC`, then
  `id DESC`.
- Filter option ordering is deterministic: plans by case-insensitive captured
  plan name then plan ID; muscles by case-insensitive persisted muscle name then
  token.
- `mix precommit` passes.

Contract: `docs/design/WORKOUT_LIFECYCLE_AND_HISTORY.md`.

Out of scope for this branch:

- retroactive snapshot reconstruction
- new charts, badges, streaks, or post-workout summary pages
