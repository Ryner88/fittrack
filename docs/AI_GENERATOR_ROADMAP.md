# AI Generator Roadmap

This file tracks larger AI workout generator work that is not active in
`PRIORITY_FIXES.md`.

## Current Status

- The authenticated generator is implemented at `/workout-plans/generator`.
- Route placement is the existing authenticated workspace:
  `scope "/", FittrackWeb`, `pipe_through [:browser, :require_authenticated_user]`,
  `live_session :require_authenticated_user`. This is required because generated
  and saved plans are user-scoped through `current_scope`.
- The generator builds editable draft workout plans from user goals, schedule,
  equipment, experience, training styles, split preferences, duration, and
  optional source links or pasted workout text.
- Source parsing uses `Req` for HTTP fetches and the configured
  `Fittrack.Training.OpenAIWorkoutParserClient` when `OPENAI_API_KEY` is
  available.
- Parsed source exercises are normalized into structured workout JSON, matched
  against FitTrack exercise templates, expanded with curated substitutions, and
  constrained to persisted exercise/template-backed records before review.
- Plans are previewed and edited before persistence; they are not auto-saved on
  generation.
- Generated and reviewed plan exercises support set types through
  `workout_plan_exercises.target_kind`.
- Current safeguards include source URL validation, source-only no-fallback
  behavior when no structured exercises are detected, bounded volume/reps/rest
  normalization, and safety messaging in generated notes.

## Remaining Roadmap

- Persist prompt/input/output traces, validation failures, user edits, and
  accepted plans for future evals and tuning.
- Add a stricter versioned JSON schema contract around LLM parser output.
- Add explicit injury, pain, contraindication, and medical limitation inputs
  with clearer safety copy and conservative generation behavior.
- Add regression/eval fixtures for source-link parsing quality and generated
  plan validation.
- Consider a fully LLM-planned generation path after the deterministic planner
  has enough accepted-plan telemetry.
