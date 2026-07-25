# FitTrack Mobile

FitTrack mobile uses a versioned Phoenix JSON API under `/api/v1` and an Expo client in `mobile/`.

## API Routing And Auth

Mobile API routes are defined in `lib/fittrack_web/router.ex`:

- `scope "/api/v1", FittrackWeb.Api.V1`
- `pipe_through :api` for JSON parsing
- `POST /api/v1/auth/login` is unauthenticated so mobile clients can exchange email and password for a bearer token
- All other mobile routes use `pipe_through :require_mobile_api_user`

The `:require_mobile_api_user` plug validates `Authorization: Bearer <token>`, assigns `conn.assigns.current_scope`, and all protected endpoints pass that scope into context functions. This matches the generated auth guidance: API authorization is handled at the router/pipeline layer, and contexts filter data through `current_scope.user`.

Bearer tokens are stored in `users_tokens` with context `mobile_api`. The API stores only a SHA-256 hash of the bearer token and can revoke a single mobile token through `DELETE /api/v1/auth/logout`.

## API Endpoints

Authentication:

- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `DELETE /api/v1/auth/logout`

Exercise library:

- `GET /api/v1/exercise-templates`
- `GET /api/v1/exercise-templates/:id`
- `POST /api/v1/exercise-templates/:template_id/add`
- `GET /api/v1/exercises`
- `POST /api/v1/exercises`
- `GET /api/v1/exercises/:id`
- `PATCH /api/v1/exercises/:id`
- `DELETE /api/v1/exercises/:id`

Workouts and sets:

- `GET /api/v1/workouts`
- `GET /api/v1/workouts/active`
- `POST /api/v1/workouts`
- `GET /api/v1/workouts/:id`
- `PATCH /api/v1/workouts/:id`
- `DELETE /api/v1/workouts/:id`
- `GET /api/v1/workouts/:workout_id/sets`
- `POST /api/v1/workouts/:workout_id/sets`
- `PATCH /api/v1/sets/:id`
- `DELETE /api/v1/sets/:id`

History:

- `GET /api/v1/history?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`
- `GET /api/v1/history/dates`

`/api/v1/workout-sessions` is also routed to the workout controller as a mobile-friendly alias over the existing `workout_sessions` table.

## Cached Exercise Media

API serializers only return cached local media records:

```json
{
  "media": [
    {
      "id": 123,
      "kind": "image",
      "url": "/exercise-media/123",
      "mime_type": "image/png"
    }
  ]
}
```

Remote provider URLs are not exposed in mobile JSON responses. Mobile clients should fetch the provided local URL from the Phoenix host.

## Mobile Environment

Install and start the Expo app:

```sh
cd mobile
npm install
EXPO_PUBLIC_API_BASE_URL=http://localhost:4000/api/v1 npm start
```

Use your machine LAN IP instead of `localhost` when testing on a physical device:

```sh
EXPO_PUBLIC_API_BASE_URL=http://192.168.1.10:4000/api/v1 npm start
```

For Android emulator networking, `http://10.0.2.2:4000/api/v1` is usually the correct base URL.

## Local Draft Recovery

The Expo client persists:

- mobile bearer token
- signed-in user summary
- active workout draft
- pending sets that could not be synced

Drafts are stored with `@react-native-async-storage/async-storage`. If the app is interrupted, the next launch reloads the active draft and resumes logging. When a set sync fails, it remains in `pendingSets` until the user retries by continuing the workout.

## Release Workflow

Backend:

```sh
mix precommit
```

Mobile:

```sh
cd mobile
npm install
npm run start
npm run android
npm run ios
```

Before store builds, set `EXPO_PUBLIC_API_BASE_URL` to the production API URL and confirm:

- login succeeds
- `/api/v1/auth/me` returns the expected user
- exercise templates return local `/exercise-media/:id` URLs
- a workout can be started and a set can be logged
- interrupted active workouts recover after app restart
