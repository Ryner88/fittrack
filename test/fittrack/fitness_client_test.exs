defmodule Fittrack.FitnessClientTest do
  use ExUnit.Case, async: false

  alias Fittrack.FitnessClient

  defmodule HttpClientStub do
    def get(url, _headers) do
      send(self(), {:http_get, url})
      {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"ok":true})}}
    end
  end

  defmodule HttpClientExercisesStub do
    def get(_url, _headers) do
      body = ~s({"exercises":[],"pagination":{"page":1,"pageSize":20,"totalCount":0,"hasMore":false}})
      {:ok, %HTTPoison.Response{status_code: 200, body: body}}
    end
  end

  defmodule HttpClientUnauthorizedStub do
    def get(_url, _headers) do
      {:ok, %HTTPoison.Response{status_code: 401, body: ~s({"error":"Authentication required."})}}
    end
  end

  @test_key "test-api-key-that-is-long-enough-to-pass-64-char-check-xxxxxxxxxx"

  setup do
    Application.put_env(:fittrack, FitnessClient,
      base_url: "http://127.0.0.1:3010",
      api_key: @test_key,
      http_client: HttpClientStub
    )
    on_exit(fn -> Application.delete_env(:fittrack, FitnessClient) end)
    :ok
  end

  test "get_exercises hits /api/v2/exercises/search" do
    Application.put_env(:fittrack, FitnessClient,
      base_url: "http://127.0.0.1:3010",
      api_key: @test_key,
      http_client: HttpClientExercisesStub
    )
    {:ok, result} = FitnessClient.get_exercises()
    assert Map.has_key?(result, "exercises")
    assert Map.has_key?(result, "pagination")
  end

  test "search_exercises passes query params to /api/v2/exercises/search" do
    {:ok, _} = FitnessClient.search_exercises(search_term: "bench")
    assert_received {:http_get, url}
    assert url =~ "/api/v2/exercises/search"
    assert url =~ "searchTerm=bench"
  end

  test "search_exercises passes equipment filter" do
    {:ok, _} = FitnessClient.search_exercises(equipment: "barbell")
    assert_received {:http_get, url}
    assert url =~ "equipmentFilter=barbell"
  end

  test "returns error tuple on 401 response" do
    Application.put_env(:fittrack, FitnessClient,
      base_url: "http://127.0.0.1:3010",
      api_key: @test_key,
      http_client: HttpClientUnauthorizedStub
    )
    assert {:error, reason} = FitnessClient.get_exercises()
    assert reason =~ "Unauthorized"
  end

  test "raises if api_key is not configured" do
    Application.put_env(:fittrack, FitnessClient,
      base_url: "http://127.0.0.1:3010",
      api_key: nil,
      http_client: HttpClientStub
    )
    assert_raise RuntimeError, ~r/SPARKY_API_KEY/, fn ->
      FitnessClient.get_exercises()
    end
  end
end
