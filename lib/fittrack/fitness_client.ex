defmodule Fittrack.FitnessClient do
  @moduledoc """
  Read-only client for the SparkyFitness exercise library.

  Used to search and browse exercises. Fittrack handles its own
  workout logging — this module is a data source only.

  Configuration (in config/runtime.exs):
    config :fittrack, Fittrack.FitnessClient,
      base_url: System.get_env("SPARKY_BASE_URL", "http://127.0.0.1:3010"),
      api_key: System.get_env("SPARKY_API_KEY")
  """

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

  @doc """
  Search the exercise library by name, equipment, or muscle group.

  Options:
    - search_term: substring match (e.g. "bench")
    - equipment: comma-separated list (e.g. "barbell,dumbbell")
    - muscle_group: comma-separated list (e.g. "chest,triceps")
    - page: page number, default 1
    - page_size: results per page, max 100, default 20

  Returns {:ok, %{"exercises" => [...], "pagination" => %{...}}}

  Example:
    {:ok, %{"exercises" => exercises}} =
      Fittrack.FitnessClient.search_exercises(search_term: "squat")
  """
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

  @doc """
  Returns the first page of all exercises (20 results).
  Use search_exercises/1 with page/page_size for more.
  """
  def get_exercises, do: search_exercises([])

  # ============================================================================
  # HTTP helpers
  # ============================================================================

  def get(path, params \\ %{}) do
    url = build_url(path, params)

    case http_client().get(url, auth_headers()) do
      {:ok, %{status_code: s, body: body}} when s in 200..299 -> decode(body)
      {:ok, %{status_code: 401}} -> {:error, "Unauthorized — check SPARKY_API_KEY"}
      {:ok, %{status_code: s, body: body}} -> {:error, "HTTP #{s}: #{body}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp build_url(path, params) do
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