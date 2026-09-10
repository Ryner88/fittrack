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

- Add linked-plan filtering for completed workouts using the immutable captured
  plan origin data.
- Add trained-muscle filtering using persisted workout muscle summaries.
- Keep date/calendar selection behavior as the primary filter. Linked-plan and
  muscle filters refine only the selected-day workout list.
- Keep calendar workout counts, monthly statistics, and global summary
  statistics unfiltered.
- Preserve ownership-scoped context reads by passing `current_scope` and
  filtering through `current_scope.user`.
- Keep manual workouts, legacy workouts without snapshots, and workouts without
  muscle summaries visible when no matching advanced filter is selected.
- Add stable DOM IDs for new filter controls and result states.
- Keep advanced filters as single-select LiveView state, not URL parameters.
- Preserve existing UTC calendar-date semantics for `started_at`.

Filter semantics:

- The selected calendar date is the primary result boundary.
- Linked-plan and muscle filters refine only the selected-day workout list.
- Calendar counts, monthly statistics, and global summary statistics remain
  unfiltered.
- Filters combine using `date AND linked_plan_id AND muscle_token` semantics.
- Blank plan or muscle values mean "all", not `NULL`.
- Plan identity comes from captured `source_workout_plan_id`, not the live plan
  association.
- Plan options are derived from user-owned completed workout origin snapshots.
- Plan option labels use the most recently captured `plan_name` for each
  `source_workout_plan_id`.
- Selecting a plan ID matches all historical snapshots for that plan ID,
  including snapshots captured under earlier names.
- Deleted plans remain selectable because options do not depend on the live plan
  table.
- Manual or legacy workouts without snapshots do not match a selected plan
  filter.
- Muscle identity comes from persisted `muscle_token`, not display name.
- A workout matches a muscle filter if any persisted summary has the selected
  token; primary and secondary roles both qualify.
- Multiple summary rows for the same token do not duplicate a workout.
- Muscle option display names come from persisted summaries.
- Workouts without muscle summaries do not match a selected muscle filter.
- Invalid or stale plan and muscle values fall back to "all".
- Month navigation clears the selected date and selected-day results, but
  preserves advanced-filter selections.
- Clearing either advanced filter immediately reloads selected-day results when
  a date is selected.

Acceptance:

- Filter queries only return `completed` workouts owned by the current user.
- Plan filters match workouts by captured source plan identity or copied plan
  context and continue working after the live reusable plan is renamed or
  deleted.
- Muscle filters match persisted primary and secondary muscle summary rows.
- Combining date, linked-plan, and muscle filters produces the expected
  intersection without changing the existing calendar UX.
- Empty filtered states are explicit and covered by LiveView tests using stable
  selectors.
- Selected-day filtering uses stable DOM IDs:
  `#history-plan-filter`, `#history-muscle-filter`, `#history-clear-filters`,
  `#history-no-date-selected`, and `#history-no-filtered-results`.
- Filtered-empty state says no workouts match the selected filters, distinct
  from the no-completed-workouts-on-date state.
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
- Existing calendar counts and summary statistics retain their unfiltered
  behavior.
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
