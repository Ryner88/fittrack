# AI Workout Generator Feature

## Overview

The **AI Workout Generator** creates personalized 4-week workout plan drafts
inside the authenticated training workspace. Users specify prioritized goals,
experience level, available equipment, training styles, split preferences,
duration, and optional workout links or pasted source text. The generated result
is reviewed and edited before it is saved to the user's workout plans.

## Features

### Intelligent Plan Generation

- **Goal-Based Customization**: Generates plans optimized for strength, hypertrophy, endurance, fat loss, or general fitness
- **Experience-Aware**: Adjusts sets, rep ranges, and rest periods based on beginner/intermediate/advanced levels
- **Equipment Flexibility**: Works with bodyweight, dumbbells, barbells, kettlebells, machines, and resistance bands
- **Weekly Scheduling**: Distributes exercises across 1-7 days per week as specified by the user
- **4-Week Progression**: Built-in guidance to progress loads 2.5-5% weekly for continuous improvement
- **Source-Guided Drafts**: Can analyze readable workout articles, video pages,
  or pasted transcripts and convert structured exercises into draft plan entries
- **Review Before Save**: Drafts expose editable plan name, notes, duration,
  sets, reps, rest, set type, exercise notes, and order before persistence

### Core Functionality

| Aspect | Implementation |
|--------|-----------------|
| **Draft Generation** | `Fittrack.Training.preview_ai_workout_plan/2` in backend |
| **Plan Persistence** | `Fittrack.Training.generate_ai_workout_plan/2` and reviewed `create_workout_plan/2` paths |
| **UI** | `FittrackWeb.WorkoutPlanLive.Generator` LiveView |
| **Routing** | Authenticated `/workout-plans/generator` route |
| **Database** | Leverages existing `workout_plans` and `workout_plan_exercises` tables |
| **Source Parser** | `Fittrack.Training.OpenAIWorkoutParserClient` with `Req` and `OPENAI_API_KEY` |

The route lives in `scope "/", FittrackWeb`,
`pipe_through [:browser, :require_authenticated_user]`, and
`live_session :require_authenticated_user` because the generator creates and
saves user-owned workout plans through `current_scope`.

## User Workflow

1. **Access Generator**: Click "AI Generator" button on `/workout-plans` index
2. **Input Parameters**:
   - Prioritized goals (strength / hypertrophy / endurance / fat_loss / general)
   - Experience Level (beginner / intermediate / advanced)
   - Available Equipment (checkboxes for multiple selections)
   - Training styles and split preferences
   - Days per Week (1-7)
   - Duration (15-180 minutes)
   - Optional source URL or pasted workout text
3. **Plan Generation**: System generates a draft with exercises, sets, reps,
   rest periods, schedule days, notes, and target set types
4. **Review Draft**: User edits the draft before saving
5. **Save Plan**: Reviewed draft is persisted to the user's workout plans

## Technical Implementation

### Backend: `preview_ai_workout_plan/2`

```elixir
def preview_ai_workout_plan(%Scope{} = scope, attrs) when is_map(attrs) do
  primary_goal = Map.get(attrs, "primary_goal", "general") |> normalize_goal_preference()
  experience = Map.get(attrs, "experience", "beginner") |> String.downcase()
  equipment = normalize_equipment_input(Map.get(attrs, "equipment", []))
  days_per_week = parse_int(Map.get(attrs, "days_per_week", 4), 4)
  duration_minutes = parse_int(Map.get(attrs, "duration_minutes", 45), 45)

  # Validates inputs, fetches/matches exercises, and returns draft attrs.
  {:ok, %{...}}
end
```

**Key Helpers**:
- `normalize_equipment_input/1`: Converts equipment string/list to normalized format
- `experience_to_sets/1`: Returns target set count (3/4/5 for beginner/intermediate/advanced)
- `goal_to_rep_range/1`: Returns (min_reps, max_reps) tuple based on goal
- `days_for_week/1`: Maps days count to scheduled days (e.g., 3 → ["Monday", "Wednesday", "Friday"])
- `build_workout_plan_exercises/12`: Orchestrates generated or source-derived
  exercise assignment with rep/set/rest/set-type config
- `OpenAIWorkoutParserClient.parse_workout_text/2`: Converts source text into
  structured workout JSON when `OPENAI_API_KEY` is configured

### Frontend: Generator LiveView

[FittrackWeb.WorkoutPlanLive.Generator](lib/fittrack_web/live/workout_plan_live/generator.ex)

**States**:
- Renders form with goal/experience/equipment selectors
- On submit: calls `Training.preview_ai_workout_plan/2`
- Success → renders `#ai-workout-draft-review` and `#ai-workout-draft-form`
- Save reviewed plan → calls `Training.create_workout_plan/2` and redirects to the plan show page
- Error → displays user-friendly error message

### Data Model

**Generated Plan Structure**:
```
WorkoutPlan
├── name: "AI Workout Plan (Hypertrophy) - 2026-04-02"
├── goal: "hypertrophy"
├── difficulty: "beginner"
├── primary_style: "bodybuilding"
├── estimated_duration_minutes: 45
└── workout_plan_exercises: [
    {position: 1, exercise_id: X, target_sets: 3, target_reps_min: 8, 
     target_reps_max: 12, rest_seconds: 60, target_kind: "working_set",
     scheduled_day: "Monday"},
    ...
  ]
```

## Exercise Selection Algorithm

1. **Parse Source Input**: Optional links/text are summarized and, when
   configured, parsed into structured exercises.
2. **Match Templates**: Source names and equipment preferences are matched
   against normalized exercise templates and aliases.
3. **Expand Substitutions**: Curated substitutions are included so the generator
   can use suitable alternatives.
4. **Create User Exercises**: Selected templates are copied into the user's
   exercise library before draft persistence.
5. **Fallback Pool**: Manual generation uses matching templates and personal
   exercises when no source-specific structure is provided.
6. **Daily Distribution**: Generated plans rotate through the pool across
   scheduled days.
   - 6+ exercises → 5 per day
   - 4-5 exercises → 4 per day
   - <4 exercises → 3 per day

Example: For 3 days/week with 5 available exercises:
- Monday: exercises 0-4
- Wednesday: exercises 0-4 (rotated offset)
- Friday: exercises 0-4 (rotated offset)

## Configuration by Experience Level

| Level | Sets | Rest (s) | Reps | Entry-Level Styles |
|-------|------|----------|------|-------------------|
| Beginner | 3 | 60 | 8-12 | Bodybuilding, Beginner |
| Intermediate | 4 | 90 | 8-12 | Bodybuilding, Hypertrophy |
| Advanced | 5 | 120 | 8-12 | Strength, Powerlifting |

## Goal-Based Configuration

| Goal | Primary Style | Rep Range | Use Case |
|------|---------------|-----------|----------|
| Strength | strength | 4-6 | Max effort, neural adaptation |
| Hypertrophy | hypertrophy | 8-12 | Muscle building |
| Endurance | conditioning | 12-20 | Muscular endurance |
| Fat Loss | conditioning | 10-15 | High volume, calorie deficit |
| General | bodybuilding | 8-12 | Balanced development |

## Testing

**Unit Tests** ([test/fittrack/training_test.exs](test/fittrack/training_test.exs)):
- ✅ `generate_ai_workout_plan/2 generates and saves workflow plan`
- Covers plan creation, WGER-backed template selection, curated substitution
  expansion, duplicate-goal validation, and metadata

**LiveView Tests** ([test/fittrack_web/live/workout_plan_live/generator_test.exs](test/fittrack_web/live/workout_plan_live/generator_test.exs)):
- ✅ `renders generator and creates a plan`
- Covers form rendering, source analysis states, draft review, reviewed draft
  saving, source-only fallback behavior, parser failures, and validation states

Current verification is tracked in `docs/FIXED_WORK.md` and the project-wide
`mix precommit` alias.

## Key Files

1. **Backend Logic**:
   - [lib/fittrack/training.ex](lib/fittrack/training.ex) — Core preview/generation helpers
   - [lib/fittrack/training/openai_workout_parser_client.ex](lib/fittrack/training/openai_workout_parser_client.ex) — OpenAI-backed source parser
   - [lib/fittrack/training/workout_plan_exercise.ex](lib/fittrack/training/workout_plan_exercise.ex) — Planned exercise targets and set type

2. **Frontend**:
   - [lib/fittrack_web/live/workout_plan_live/generator.ex](lib/fittrack_web/live/workout_plan_live/generator.ex) — Generator and draft-review LiveView
   - [lib/fittrack_web/live/workout_plan_live/index.ex](lib/fittrack_web/live/workout_plan_live/index.ex) — "AI Generator" entry point

3. **Routing**:
   - [lib/fittrack_web/router.ex](lib/fittrack_web/router.ex) — authenticated `/workout-plans/generator` route

4. **Tests**:
   - [test/fittrack/training_test.exs](test/fittrack/training_test.exs) — Backend test
   - [test/fittrack_web/live/workout_plan_live/generator_test.exs](test/fittrack_web/live/workout_plan_live/generator_test.exs) — LiveView test

## Usage Guide

### For Users

1. Navigate to **Workout Plans** section
2. Click **"AI Generator"** button (rocket icon)
3. Fill out the form:
   - Select your **fitness goal**
   - Choose your **experience level**
   - Check available **equipment**
   - Enter **days per week** you can train
   - Optionally paste a source link or transcript
4. Click **"Generate Draft"**
5. Review and edit the draft
6. Click **"Save Reviewed Plan"**

### For Developers

Generate a plan programmatically:

```elixir
scope = %Fittrack.Accounts.Scope{user: user}

params = %{
  "goal" => "hypertrophy",
  "experience" => "beginner",
  "equipment" => ["Dumbbells", "Bodyweight"],
  "days_per_week" => 4
}

{:ok, workout_plan} = Fittrack.Training.generate_ai_workout_plan(scope, params)
```

## Future Enhancements

- [ ] Periodization templates (linear, undulating, block)
- [ ] Plan progression for multi-week cycles
- [ ] Persist prompt/source/parser traces and accepted-plan edits for evals
- [ ] Version the structured parser schema and add source-parsing eval fixtures
- [ ] REST day optimization based on muscle recovery science
- [ ] Export plans as PDF/mobile-friendly format

## Error Handling

| Error | Cause | Resolution |
|-------|-------|-----------|
| "No exercises available..." | User has no exercises for equipment | Create exercises or use built-in templates |
| "Days per week must be 1-7" | Invalid input | Ensure input is an integer in range [1-7] |
| "Unauthorized" | Not authenticated | Log in first |
| Changeset error | Validation failure | Check parameter types and values |

## Notes

- Plans are reviewed before saving and can still be edited through the normal plan edit flow
- Exercise pool is randomized each generation for variety
- Rep ranges match scientifically-backed protocols for each goal
- All plans include weekly progression guidance (2.5-5% load increase)
- Plans appear in the user's Workout Plans list after the reviewed draft is saved
