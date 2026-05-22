# SparkyFitness API Integration Guide

This document explains how to use the new `Fittrack.FitnessClient` module to interact with the SparkyFitness API.

## Setup

### 1. Dependencies Added

The following dependencies have been added to `mix.exs`:

```elixir
{:httpoison, "~> 2.0"},
```

Note: `{:jason, "~> 1.4"}` was already in deps, so it wasn't duplicated.

Run `mix deps.get` to install:
```bash
mix deps.get
```

### 2. Configuration

Add environment variables to your `.env` or deployment config:

```bash
SPARKY_EMAIL=your-email@example.com
SPARKY_PASSWORD=your-password
SPARKY_BASE_URL=http://127.0.0.1:3010  # or your SparkyFitness server URL
```

These are automatically loaded in `config/runtime.exs`:

```elixir
config :fittrack, Fittrack.FitnessClient,
  base_url: System.get_env("SPARKY_BASE_URL", "http://127.0.0.1:3010"),
  email: System.get_env("SPARKY_EMAIL"),
  password: System.get_env("SPARKY_PASSWORD")
```

> The client automatically prefixes API calls with `/api`, so `base_url` should point to the server root, not the API root.
### 3. Initialization

The token cache Agent is initialized automatically when the application starts. This is handled in `lib/fittrack/application.ex`:

```elixir
def start(_type, _args) do
  # Initialize the FitnessClient token cache
  Fittrack.FitnessClient.init_token_cache()
  
  children = [
    # ... other children
  ]
end
```

## Usage

### Authentication

#### Get a Token (Cached)

```elixir
{:ok, token} = Fittrack.FitnessClient.get_token()
```

This will:
- Return the cached token if available
- Perform a login automatically if no cached token exists
- Cache the token for subsequent requests

#### Manual Login

```elixir
{:ok, token} = Fittrack.FitnessClient.login()
```

This always performs a login and updates the cache.

### Exercise API

#### Log an Exercise

```elixir
{:ok, result} = Fittrack.FitnessClient.log_exercise(123, [
  %{reps: 10, weight: 225},
  %{reps: 8, weight: 235},
  %{reps: 5, weight: 245}
])
```

Parameters:
- `exercise_id`: The ID of the exercise
- `sets`: List of set objects, each containing:
  - `reps`: Number of repetitions (integer)
  - `weight`: Weight lifted in lbs/kg (optional, number)
  - `duration`: Duration in seconds (optional, integer)
  - `rest_time`: Rest time in seconds (optional, integer)

#### Get All Exercises

```elixir
{:ok, exercises} = Fittrack.FitnessClient.get_exercises()
```

#### Get a Specific Exercise

```elixir
{:ok, exercise} = Fittrack.FitnessClient.get_exercise(123)
```

#### Get Exercise Logs/History

```elixir
{:ok, logs} = Fittrack.FitnessClient.get_exercise_logs(123, limit: 20, offset: 0)
```

#### Health Check

```elixir
{:ok, status} = Fittrack.FitnessClient.health_check()
```

#### Get Diary by Date

```elixir
{:ok, diary} = Fittrack.FitnessClient.get_diary("2026-05-22")
```

### Generic Requests

#### GET Request

```elixir
{:ok, data} = Fittrack.FitnessClient.get("/some/api/path")
```

#### POST Request

```elixir
{:ok, result} = Fittrack.FitnessClient.post("/some/api/path", %{key: "value"})
```

## Token Management & Auto Re-login

### How It Works

1. **First Request**: Calls `get_token()` which checks the cache
   - If cached token exists, use it
   - If no cached token, perform `login()`

2. **Unauthorized (401) Response**: Atomically clears token and re-logs in
   - If a request receives a 401 response, an atomic `Agent.get_and_update` checks and clears the token
   - Only ONE concurrent process proceeds to re-login (prevents thundering herd)
   - Other concurrent processes requesting 401 get an error (avoiding multiple simultaneous logins)
   - The process that re-logged in retries the original request with the new token
   - This happens only once per request (no infinite retry loops)

### Thread-Safe Token Management

The token cache uses `Agent.get_and_update` for atomic check-and-set operations:

```elixir
Agent.get_and_update(@token_agent_name, fn
  nil -> {:already_cleared, nil}          # Another process is handling it
  _token -> {:cleared_by_us, nil}         # We're handling it
end)
```

This ensures:
- ✅ No race conditions when multiple requests get 401 simultaneously
- ✅ Only one process performs the expensive login operation
- ✅ Other processes don't waste resources on concurrent logins
- ✅ All processes are eventually notified when a new token is cached

### Example Flow with Multiple Concurrent Requests

```elixir
# Scenario: 3 concurrent requests all get 401 at the same time

Process A: get_and_update → Finds token, clears it, proceeds to login
Process B: get_and_update → Finds nil (A already cleared), skips login
Process C: get_and_update → Finds nil (A already cleared), skips login

Process A: Completes login, new token cached
Process A: Retries original request ✅ succeeds
Process B: Returns error "another process is re-logging in"
Process C: Returns error "another process is re-logging in"

# On next request, B and C will call get_token():
# - Finds cached token from A's login
# - Proceeds normally ✅
```

## Error Handling

All functions return `{:ok, result}` or `{:error, reason}`:

```elixir
case Fittrack.FitnessClient.log_exercise(123, sets) do
  {:ok, result} ->
    IO.inspect(result)
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Switching from Wger to SparkyFitness

If you were previously using the wger API, switching to SparkyFitness is simple:

### Key Differences

1. **Sets Parameter**: SparkyFitness includes sets directly in the log request body
   - Old (wger): Separate API calls for each set
   - New (SparkyFitness): Pass `sets` array in single request

2. **Base URL**: Update `SPARKY_BASE_URL` environment variable
   - Local dev: `http://127.0.0.1:3010`
   - Production: Update to your SparkyFitness server

### Migration Example

```elixir
# Old wger code
{:ok, exercise} = WgerClient.get_exercise(123)
{:ok, log} = WgerClient.log_exercise(123, reps: 10, weight: 225)

# New SparkyFitness code
{:ok, exercise} = Fittrack.FitnessClient.get_exercise(123)
{:ok, log} = Fittrack.FitnessClient.log_exercise(123, [
  %{reps: 10, weight: 225}
])
```

## Troubleshooting

### "SPARKY_EMAIL and SPARKY_PASSWORD must be configured"

Ensure these environment variables are set:
```bash
export SPARKY_EMAIL=your-email@example.com
export SPARKY_PASSWORD=your-password
```

### "HTTP 404" Errors

The SparkyFitness API routes may differ slightly from expected. Check against the live backend documentation. Common routes:
- `GET /exercises` - List all exercises
- `GET /exercises/:id` - Get specific exercise
- `POST /exercises/:id/log` - Log an exercise
- `GET /exercises/:id/logs` - Get exercise history

### Token Cache Not Working

The Agent-based cache is process-local. If your app restarts, the cache is lost and a new login is performed. This is normal behavior.

### "Unauthorized - another process is re-logging in" Error

This is **expected behavior** when multiple requests receive 401 responses concurrently. To prevent the thundering herd problem (all processes trying to login at once), only one process performs the re-login:

- **Process A**: Atomically clears token and logs in
- **Process B** & **C**: See token is already cleared, return this error
- **On next attempt**: All processes benefit from Process A's new token

This design:
- Protects the login endpoint from being hammered
- Ensures only one expensive login operation occurs
- Allows other processes to retry naturally on subsequent requests

If you see this error occasionally during high concurrency, it's working as designed.

## Implementation Details

### Token Cache with Atomic Operations

The token cache uses Elixir's `Agent` with atomic `get_and_update` operations:

```elixir
# Single atomic operation: check and clear token
Agent.get_and_update(@token_agent_name, fn
  nil -> {:already_cleared, nil}      # Returns :already_cleared
  _token -> {:cleared_by_us, nil}     # Returns :cleared_by_us and clears cache
end)
```

Benefits:
- **No race conditions**: Only one process clears the token
- **Efficient**: Single operation instead of separate get/update calls
- **Predictable**: Caller knows exactly who won the race

### Request Flow

```
make_request(method, path, body, retry: true)
  ├─ get_token() → check cache or login
  ├─ do_request() → make HTTP call with Bearer token
  │   └─ On 401: clear_and_check_cache() [atomic]
  │       ├─ Returns :cleared_by_us → this process logs in
  │       └─ Returns :already_cleared → another process is handling it
  └─ decode_response() → parse JSON response
```

### Configuration Precedence

1. Environment variables (highest priority)
2. Defaults in `config/runtime.exs`
3. Fallback values in code

Example:
```elixir
base_url = Keyword.get(config, :base_url, "http://127.0.0.1:3010")
```

## Example Controller Usage

```elixir
defmodule FittrackWeb.ExerciseController do
  def log_set(conn, %{"exercise_id" => exercise_id, "sets" => sets}) do
    sets_data = Enum.map(sets, &parse_set/1)
    
    case Fittrack.FitnessClient.log_exercise(exercise_id, sets_data) do
      {:ok, result} ->
        json(conn, result)
        
      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: reason})
    end
  end
  
  defp parse_set(%{"reps" => reps, "weight" => weight} = set) do
    %{
      reps: reps,
      weight: weight,
      duration: Map.get(set, "duration"),
      rest_time: Map.get(set, "rest_time")
    }
  end
end
```

## Testing

Quick test in `iex`:

```elixir
iex> Fittrack.FitnessClient.init_token_cache()
:ok

iex> Fittrack.FitnessClient.login()
{:ok, "eyJ0eXAiOiJKV1QiLCJhbGc..."}

iex> Fittrack.FitnessClient.get_exercises()
{:ok, [%{"id" => 1, "name" => "Bench Press"}, ...]}

iex> Fittrack.FitnessClient.log_exercise(1, [%{reps: 10, weight: 225}])
{:ok, %{"id" => ..., "sets" => [...]}}
```

## Additional Resources

- [SparkyFitness API Docs](http://127.0.0.1:3010/docs) (local dev)
- [HTTPoison Documentation](https://hexdocs.pm/httpoison/)
- [Jason Documentation](https://hexdocs.pm/jason/)
- [Elixir Agent Documentation](https://hexdocs.pm/elixir/Agent.html)
