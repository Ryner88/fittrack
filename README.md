# FitTrack

FitTrack is a Phoenix/LiveView web app for logging training and nutrition in one authenticated workspace. It combines reusable workout templates, active workout logging, exercise reference media, meal planning, nutrition imports, workout history, and strength tools.

## Core Features

- Workout logging with active workout sessions, performed sets, set types, rest notes, and exercise media references.
- Workout plans as reusable templates, including start-from-plan flows.
- AI workout generator for drafting editable workout plans from goals, equipment, experience, and optional workout links or transcripts.
- Exercise Library backed by normalized exercise templates, aliases, muscle/equipment metadata, and cached app-owned exercise media.
- My Exercises for user-scoped exercise management.
- Nutrition dashboard with meal logging, recent meals, weekly summaries, barcode/URL/screenshot import review flows, and food library support.
- Meal planning with reusable weekly meal plans.
- Workout History for completed workout records, calendar review, volume summaries, and detail pages.
- 1RM calculator with Epley estimates, percentage loading table, and optional bodyweight-relative strength standard.

## Local Development

Prerequisites:

- Elixir `~> 1.18`
- Erlang/OTP compatible with the local Elixir version
- PostgreSQL
- Node/npm for Phoenix asset tooling

Setup and run:

```sh
mix setup
mix phx.server
```

The app will be available at http://localhost:4000 by default.

Run the standard verification command before handing off changes:

```sh
mix precommit
```

`mix precommit` compiles with warnings as errors, checks unused dependency locks, formats the codebase, and runs the test suite through the project test alias.

## Project Tracking And Branch Workflow

Project planning lives under `docs/`:

- `docs/PRIORITY_FIXES.md`: active delivery queue. Each item should include the
  Git branch intended for the work.
- `docs/FUTURE_TASKS.md`: backlog and roadmap. Promote only the next active work
  into `docs/PRIORITY_FIXES.md`.
- `docs/FIXED_WORK.md`: completed-work log. Move finished priority items here with
  verification notes.

Branch workflow:

1. Start new work from the branch named on the priority item.
2. Keep `main` deployable and use it only for reviewed, verified baseline work.
3. Run `mix precommit` before pushing or opening a pull request.
4. Merge task branches back into `main`, then prune merged branches locally
   and on GitHub.
5. Leave historical documentation references intact only when they explain
   shipped or retired work.

Current priority branch names are listed directly in `docs/PRIORITY_FIXES.md` so
the task queue and GitHub branch set stay in sync.

## Environment Variables

AI and import configuration:

- `OPENAI_API_KEY`: enables screenshot nutrition parsing and AI workout source/link parsing.
- `SCREENSHOT_IMPORT_MODEL`: overrides the screenshot nutrition parser model. Default in code is `gpt-4.1-mini`.
- `AI_WORKOUT_PARSER_MODEL`: overrides the AI workout source parser model. Default in code is `gpt-4.1-mini`.
- `WGER_API_KEY`: optional WGER API key used by WGER exercise template and media import tasks.
- `EXERCISE_MEDIA_STORAGE_ROOT`: local filesystem root for cached exercise media. Defaults to `/opt/fittrack/storage/exercise_media`.

Common Phoenix/runtime variables:

- `PORT`: HTTP port. Defaults to `4000`.
- `PHX_SERVER`: enables the endpoint server for releases when set.
- `DATABASE_URL`: required in production.
- `SECRET_KEY_BASE`: required in production.
- `PHX_HOST`: production host. Defaults to `fitness.nextgenbytes.me`.
- `POOL_SIZE`: production database pool size. Defaults to `10`.
- `ECTO_IPV6`: set to `true` or `1` to enable IPv6 socket options.
- `DNS_CLUSTER_QUERY`: optional DNS cluster query for production.
- `MAILGUN_API_KEY` and `MAILGUN_DOMAIN`: required by the production Mailgun adapter.

Test database overrides:

- `DB_USER`, `DB_PASSWORD`, `DB_HOST`, and `DB_NAME` are used by `config/test.exs`.
- `SKIP_DB_SETUP` skips the test alias database create/migrate steps and runs `mix test --no-start`.

## Useful Mix Tasks

Verified project tasks:

```sh
mix fittrack.import_exercise_templates
mix fittrack.import_exercise_templates --limit 50
mix fittrack.backfill_exercise_media --dry-run
mix fittrack.backfill_exercise_media --limit 50
mix fittrack.backfill_exercise_media --exercise-id 123
mix fittrack.clean_exercise_template_notes --dry-run
mix fittrack.import_templates priv/data/exercise_templates.json
mix fittrack.import_templates priv/data/exercise_templates.csv
```

`mix populate_exercise_images` also exists, but it is a legacy/demo helper that fills missing template image URLs with placeholders. Prefer the cached media backfill for production exercise media.

See `docs/EXERCISE_MEDIA_BACKFILL.md` for the exact cached exercise media
backfill contract, matching rules, status semantics, and production
verification gates.

## Production And Deployment

`deploy.sh` is the operational deployment script. It pulls `main`, refuses to deploy from a dirty working tree, loads `fittrack.env`, fetches production dependencies, compiles, runs migrations, deploys assets, creates the release, restarts via `_build/prod/rel/fittrack/bin/fittrack restart`, and verifies the local endpoint.

Production deployments should start from a clean working tree. Use:

```sh
./deploy.sh
```

Useful options:

```sh
./deploy.sh --skip-git
./deploy.sh --skip-restart
```
