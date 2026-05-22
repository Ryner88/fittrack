defmodule Fittrack.FitnessClient do
  @moduledoc """
  SparkyFitness API client with JWT token caching.

  This module handles all interactions with the SparkyFitness API,
  including login and token management via an Agent cache.

  Configuration (in config/runtime.exs):
    config :fittrack, Fittrack.FitnessClient,
      base_url: "http://127.0.0.1:3010",
      email: System.get_env("SPARKY_EMAIL"),
      password: System.get_env("SPARKY_PASSWORD")
  """

  require Logger

  @token_agent_name __MODULE__.TokenCache
  @api_root "/api"

  # ============================================================================
  # Token Cache Agent Management
  # ============================================================================

  @doc """
  Ensures the token cache Agent is started. Called during app startup.
  """
  def init_token_cache do
    case Agent.start_link(fn -> nil end, name: @token_agent_name) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        error
    end
  end

  defp cache_token(token) do
    Agent.update(@token_agent_name, fn _ -> token end)
  end

  defp get_cached_token do
    Agent.get(@token_agent_name, & &1)
  end

  defp api_root do
    @api_root
  end

  defp http_client do
    config = Application.get_env(:fittrack, __MODULE__) || []
    Keyword.get(config, :http_client, HTTPoison)
  end

  @doc false
  defp clear_and_check_cache do
    Agent.get_and_update(@token_agent_name, fn
      nil -> {:already_cleared, nil}
      _token -> {:cleared_by_us, nil}
    end)
  end

  # ============================================================================
  # Authentication
  # ============================================================================

  @doc """
  Logs in to SparkyFitness and returns the JWT token.

  Credentials are fetched from application config:
    - email: System.get_env("SPARKY_EMAIL")
    - password: System.get_env("SPARKY_PASSWORD")

  Returns {:ok, token} or {:error, reason}
  """
  def login do
    config = Application.get_env(:fittrack, __MODULE__) || []
    base_url = Keyword.get(config, :base_url, "http://127.0.0.1:3010")
    email = Keyword.get(config, :email)
    password = Keyword.get(config, :password)

    if !email || !password do
      {:error, "SPARKY_EMAIL and SPARKY_PASSWORD must be configured"}
    else
      login_url = "#{base_url}#{api_root()}/auth/login"

      body = Jason.encode!(%{email: email, password: password})

      case http_client().post(login_url, body, [{"Content-Type", "application/json"}]) do
        {:ok, response} ->
          case Jason.decode(response.body) do
            {:ok, %{"token" => token}} ->
              cache_token(token)
              {:ok, token}

            {:ok, data} ->
              {:error, "No token in login response: #{inspect(data)}"}

            {:error, reason} ->
              {:error, "Failed to parse login response: #{inspect(reason)}"}
          end

        {:error, reason} ->
          {:error, "Login request failed: #{inspect(reason)}"}
      end
    end
  end

  # ============================================================================
  # Token Management (with automatic re-login on Unauthorized)
  # ============================================================================

  @doc """
  Gets a valid JWT token, using cached token if available.
  If no cached token exists, performs a login.
  """
  def get_token do
    case get_cached_token() do
      token when is_binary(token) ->
        {:ok, token}

      nil ->
        login()
    end
  end

  defp handle_unauthorized do
    case clear_and_check_cache() do
      :cleared_by_us ->
        Logger.warning("Token expired (401), clearing cache and re-logging in")
        login()

      :already_cleared ->
        # Another concurrent request already cleared the token and is re-logging in.
        # Return error to prevent thundering herd on login endpoint.
        Logger.warning("Token already cleared by another process, skipping concurrent re-login")
        {:error, "Unauthorized - another process is re-logging in"}
    end
  end

  # ============================================================================
  # API Requests
  # ============================================================================

  @doc """
  Makes an authorized GET request to the SparkyFitness API.

  Returns {:ok, body} on success (with decoded JSON),
  or {:error, reason} on failure.
  """
  def get(path) do
    make_request(:get, path, nil)
  end

  @doc """
  Makes an authorized POST request to the SparkyFitness API.

  Returns {:ok, body} on success (with decoded JSON),
  or {:error, reason} on failure.
  """
  def post(path, body) do
    make_request(:post, path, body)
  end

  defp make_request(method, path, body, retry \\ true) do
    with {:ok, token} <- get_token(),
         {:ok, response} <- do_request(method, path, body, token),
         {:ok, decoded} <- decode_response(response) do
      {:ok, decoded}
    else
      {:error, "Unauthorized", _response} when retry ->
        # Token may have expired, attempt atomic re-login.
        # Only one concurrent process will actually log in.
        case handle_unauthorized() do
          {:ok, new_token} ->
            # This process successfully re-logged in, retry the request
            with {:ok, response} <- do_request(method, path, body, new_token),
                 {:ok, decoded} <- decode_response(response) do
              {:ok, decoded}
            else
              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            # Another process is already re-logging in, or login failed
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(method, path, body, token) do
    config = Application.get_env(:fittrack, __MODULE__) || []
    base_url = Keyword.get(config, :base_url, "http://127.0.0.1:3010")

    url = "#{base_url}#{api_root()}#{path}"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]

    case method do
      :get ->
        http_client().get(url, headers)

      :post ->
        body_str = if is_map(body), do: Jason.encode!(body), else: body
        http_client().post(url, body_str, headers)
    end
    |> case do
      {:ok, response} ->
        if response.status_code == 401 do
          {:error, "Unauthorized", response}
        else
          {:ok, response}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_response(%HTTPoison.Response{status_code: status_code, body: body})
       when status_code >= 200 and status_code < 300 do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, "Failed to decode response: #{inspect(reason)}"}
    end
  end

  defp decode_response(%HTTPoison.Response{status_code: status_code, body: body}) do
    case Jason.decode(body) do
      {:ok, error_data} ->
        {:error, "HTTP #{status_code}: #{inspect(error_data)}"}

      {:error, _} ->
        {:error, "HTTP #{status_code}: #{body}"}
    end
  end

  # ============================================================================
  # Exercise API
  # ============================================================================

  @doc """
  Logs an exercise to SparkyFitness.

  Parameters:
    - exercise_id: The ID of the exercise
    - sets: List of set data, each containing:
      - reps: Number of repetitions
      - weight: Weight lifted (optional)
      - duration: Duration in seconds (optional)
      - rest_time: Rest time in seconds (optional)

  Example:
    {:ok, result} = Fittrack.FitnessClient.log_exercise(123, [
      %{reps: 10, weight: 225},
      %{reps: 8, weight: 235},
      %{reps: 5, weight: 245}
    ])
  """
  def log_exercise(exercise_id, sets) when is_list(sets) do
    path = "/exercises/#{exercise_id}/log"

    body = %{
      sets: sets
    }

    post(path, body)
  end

  @doc """
  Retrieves a list of all exercises from SparkyFitness.
  """
  def get_exercises do
    get("/exercises")
  end

  @doc """
  Retrieves a specific exercise by ID.
  """
  def get_exercise(exercise_id) do
    get("/exercises/#{exercise_id}")
  end

  @doc """
  Retrieves exercise history/logs.

  Optional parameters:
    - limit: Maximum number of logs to return
    - offset: Number of logs to skip
  """
  def get_exercise_logs(exercise_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    offset = Keyword.get(opts, :offset, 0)
    path = "/exercises/#{exercise_id}/logs?limit=#{limit}&offset=#{offset}"
    get(path)
  end

  @doc """
  Checks SparkyFitness health.
  """
  def health_check do
    get("/health")
  end

  @doc """
  Retrieves exercise diary entries for a given date.
  """
  def get_diary(date) when is_binary(date) do
    get("/exercises/diary/#{date}")
  end
end
