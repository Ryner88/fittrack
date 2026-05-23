defmodule Fittrack.FitnessClient do
  @moduledoc """
  SparkyFitness API client using API key authentication.

  Configuration (in config/runtime.exs):
    config :fittrack, Fittrack.FitnessClient,
      base_url: System.get_env("SPARKY_BASE_URL", "http://127.0.0.1:3010"),
      api_key: System.get_env("SPARKY_API_KEY")

  The API key is generated in SparkyFitness under Settings -> API Key Management.
  """

  require Logger

  @api_root "/api"

  defp config, do: Application.get_env(:fittrack, __MODULE__) || []
  defp base_url, do: Keyword.get(config(), :base_url, "http://127.0.0.1:3010")
  defp api_key, do: Keyword.get(config(), :api_key)
  defp http_client, do: Keyword.get(config(), :http_client, HTTPoison)

  defp auth_headers do
    key = api_key()
    if is_nil(key) or key == "" do
      raise "SPARKY_API_KEY must be configured in Fittrack.FitnessClient"
    end
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{key}"}
    ]
  end

  def search_exercises(opts \\ []) do
    params =
      %{}
      |> maybe_put("searchTerm", opts[:search_term])
      |> maybe_put("equipmentFilter", opts[:equipment])
      |> maybe_put("muscleGroupFilter", opts[:muscle_group])
      |> maybe_put("page", opts[:page])
      |> maybe_put("pageSize", opts[:page_size])
    get("/v2/exercises/search", params)
  end

  def get_exercises, do: search_exercises([])

  def get_exercise_history(opts \\ []) do
    params =
      %{}
      |> maybe_put("page", opts[:page])
      |> maybe_put("pageSize", opts[:page_size])
      |> maybe_put("userId", opts[:user_id])
    get("/v2/exercise-entries/history", params)
  end

  def get_diary(date) when is_binary(date) do
    get("/v2/exercise-entries", %{"date" => date})
  end

  def log_exercise(exercise_id, sets) when is_list(sets) do
    post("/exercises", %{exercise_id: exercise_id, sets: sets})
  end

  def health_check, do: get("/health")

  def get(path, params \\ %{}) do
    url = build_url(path, params)
    case http_client().get(url, auth_headers()) do
      {:ok, %{status_code: s, body: body}} when s in 200..299 -> decode(body)
      {:ok, %{status_code: 401}} -> {:error, "Unauthorized — check SPARKY_API_KEY"}
      {:ok, %{status_code: s, body: body}} -> {:error, "HTTP #{s}: #{body}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def post(path, body) do
    url = build_url(path)
    case http_client().post(url, Jason.encode!(body), auth_headers()) do
      {:ok, %{status_code: s, body: resp}} when s in 200..299 -> decode(resp)
      {:ok, %{status_code: 401}} -> {:error, "Unauthorized — check SPARKY_API_KEY"}
      {:ok, %{status_code: s, body: resp}} -> {:error, "HTTP #{s}: #{resp}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp build_url(path, params \\ %{}) do
    base = "#{base_url()}#{@api_root}#{path}"
    case Enum.reject(Map.to_list(params), fn {_, v} -> is_nil(v) end) do
      [] -> base
      pairs -> base <> "?" <> URI.encode_query(pairs)
    end
  end

  defp decode(""), do: {:ok, %{}}
  defp decode(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, "Failed to decode: #{body}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
