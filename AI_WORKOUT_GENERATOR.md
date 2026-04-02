# AI Workout Generator Feature

## Overview

The **AI Workout Generator** is an intelligent fitness tool that creates personalized 4-week workout plans based on user input. Users specify their fitness goals, experience level, available equipment, and training frequency to receive a structured, ready-to-use workout plan saved to their account.

## Features

### Intelligent Plan Generation

- **Goal-Based Customization**: Generates plans optimized for strength, hypertrophy, endurance, fat loss, or general fitness
- **Experience-Aware**: Adjusts sets, rep ranges, and rest periods based on beginner/intermediate/advanced levels
- **Equipment Flexibility**: Works with bodyweight, dumbbells, barbells, kettlebells, machines, and resistance bands
- **Weekly Scheduling**: Distributes exercises across 1-7 days per week as specified by the user
- **4-Week Progression**: Built-in guidance to progress loads 2.5-5% weekly for continuous improvement

### Core Functionality

| Aspect | Implementation |
|--------|-----------------|
| **Plan Generation** | `Fittrack.Training.generate_ai_workout_plan/2` in backend |
| **UI** | `FittrackWeb.WorkoutPlanLive.Generator` LiveView |
| **Routing** | `/workout-plans/generator` route |
| **Database** | Leverages existing `workout_plans` and `workout_plan_exercises` tables |

## User Workflow

1. **Access Generator**: Click "AI Generator" button on `/workout-plans` index
2. **Input Parameters**:
   - Primary Goal (strength / hypertrophy / endurance / fat_loss / general)
   - Experience Level (beginner / intermediate / advanced)
   - Available Equipment (checkboxes for multiple selections)
   - Days per Week (1-7)
3. **Plan Generation**: System generates exercises, sets, reps, and rest periods
4. **Auto-Save**: Plan is immediately saved to user account
5. **View Plan**: User navigates to plan show page to review and start workouts

## Technical Implementation

### Backend: `generate_ai_workout_plan/2`

```elixir
def generate_ai_workout_plan(%Scope{} = scope, attrs) when is_map(attrs) do
  goal = Map.get(attrs, "goal", "general") |> String.downcase()
  experience = Map.get(attrs, "experience", "beginner") |> String.downcase()
  equipment = normalize_equipment_input(Map.get(attrs, "equipment", []))
  days_per_week = parse_int(Map.get(attrs, "days_per_week", 4), 4)
  
  # Validates inputs, fetches exercises, builds plan structure
  create_workout_plan(scope, %{...})
end
```

**Key Helpers**:
- `normalize_equipment_input/1`: Converts equipment string/list to normalized format
- `experience_to_sets/1`: Returns target set count (3/4/5 for beginner/intermediate/advanced)
- `goal_to_rep_range/1`: Returns (min_reps, max_reps) tuple based on goal
- `days_for_week/1`: Maps days count to scheduled days (e.g., 3 → ["Monday", "Wednesday", "Friday"])
- `build_workout_plan_exercises/5`: Orchestrates exercise assignment to days with proper rep/set/rest config

### Frontend: Generator LiveView

[FittrackWeb.WorkoutPlanLive.Generator](lib/fittrack_web/live/workout_plan_live/generator.ex)

**States**:
- Renders form with goal/experience/equipment selectors
- On submit: calls `Training.generate_ai_workout_plan/2`
- Success → redirects to plan show page with flash confirmation
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
     target_reps_max: 12, rest_seconds: 60, scheduled_day: "Monday"},
    ...
  ]
```

## Exercise Selection Algorithm

1. **Fetch User Exercises**: Filter by equipment if available
2. **Fallback to Templates**: If no user exercises match, create from exercise templates
3. **Shuffle Pool**: Randomize exercise order for variety
4. **Daily Distribution**: Rotate through pool across scheduled days
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
- Validates plan creation, exercise assignment, and metadata

**LiveView Tests** ([test/fittrack_web/live/workout_plan_live/generator_test.exs](test/fittrack_web/live/workout_plan_live/generator_test.exs)):
- ✅ `renders generator and creates a plan`
- Tests form rendering, submission, and plan persistence

**Test Results**: 15/15 passing

## Files Modified

1. **Backend Logic**:
   - [lib/fittrack/training.ex](lib/fittrack/training.ex) — Core `generate_ai_workout_plan/2` + helpers
   - [lib/fittrack/training/workout_plan_exercise.ex](lib/fittrack/training/workout_plan_exercise.ex) — Relaxed validation

2. **Frontend**:
   - [lib/fittrack_web/live/workout_plan_live/generator.ex](lib/fittrack_web/live/workout_plan_live/generator.ex) — New LiveView
   - [lib/fittrack_web/live/workout_plan_live/index.ex](lib/fittrack_web/live/workout_plan_live/index.ex) — Added "AI Generator" button

3. **Routing**:
   - [lib/fittrack_web/router.ex](lib/fittrack_web/router.ex) — `/workout-plans/generator` route

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
4. Click **"Generate 4-Week Plan"**
5. Review your generated plan and start a workout

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

- [ ] AI-powered exercise recommendations via Claude API
- [ ] Periodization templates (linear, undulating, block)
- [ ] Plan progression for multi-week cycles
- [ ] Exercise variation suggestions within same movement pattern
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

- Plans are immutable after generation (edit functionality exists for manual adjustments)
- Exercise pool is randomized each generation for variety
- Rep ranges match scientifically-backed protocols for each goal
- All plans include weekly progression guidance (2.5-5% load increase)
- Plans immediately appear in user's Workout Plans list after generation
