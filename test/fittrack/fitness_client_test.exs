defmodule Fittrack.FitnessClientTest do
  use ExUnit.Case, async: false

  alias Fittrack.FitnessClient

  defmodule HttpClientStub do
    def post("http://127.0.0.1:3010/api/auth/login", body, headers) do
      send(self(), {:login_request, body, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s({"token":"stub-token"})
       }}
    end

    def get("http://127.0.0.1:3010/api/health", headers) do
      send(self(), {:health_request, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s({"status":"UP"})
       }}
    end

    def get("http://127.0.0.1:3010/api/exercises/diary/2026-05-22", headers) do
      send(self(), {:diary_request, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s({"entries":[]})
       }}
    end

    def get("http://127.0.0.1:3010/api/exercises", headers) do
      send(self(), {:exercises_request, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s([{"id":1,"name":"Bench Press"}])
       }}
    end

    def get(url, _headers) do
      {:error, {:unexpected_url, url}}
    end
  end

  defmodule HttpClientRetryStub do
    def post("http://127.0.0.1:3010/api/auth/login", body, headers) do
      send(self(), {:login_request, body, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s({"token":"retry-token"})
       }}
    end

    def get("http://127.0.0.1:3010/api/exercises", headers) do
      count = Process.get(:exercise_request_count, 0)
      Process.put(:exercise_request_count, count + 1)

      if count == 0 do
        {:ok,
         %HTTPoison.Response{
           status_code: 401,
           body: ~s({"error":"Authentication required."})
         }}
      else
        send(self(), {:exercise_request_after_retry, headers})

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: ~s([{"id":2,"name":"Squat"}])
         }}
      end
    end

    def get(url, _headers) do
      {:error, {:unexpected_url, url}}
    end
  end

  defmodule HttpClientErrorStub do
    def post("http://127.0.0.1:3010/api/auth/login", body, headers) do
      send(self(), {:login_request, body, headers})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body: ~s({"token":"error-token"})
       }}
    end

    def get("http://127.0.0.1:3010/api/exercises", _headers) do
      {:ok,
       %HTTPoison.Response{
         status_code: 500,
         body: ~s({"error":"Server error"})
       }}
    end

    def get(url, _headers) do
      {:error, {:unexpected_url, url}}
    end
  end

  setup do
    Application.put_env(:fittrack, Fittrack.FitnessClient, [
      base_url: "http://127.0.0.1:3010",
      email: "test@example.com",
      password: "password",
      http_client: HttpClientStub
    ])

    FitnessClient.init_token_cache()
    Agent.update(Fittrack.FitnessClient.TokenCache, fn _ -> nil end)

    on_exit(fn -> Application.delete_env(:fittrack, Fittrack.FitnessClient) end)

    :ok
  end

  test "login posts to /api/auth/login" do
    assert {:ok, "stub-token"} = FitnessClient.login()
    assert_received {:login_request, body, headers}
    assert headers == [{"Content-Type", "application/json"}]
    assert body == Jason.encode!(%{email: "test@example.com", password: "password"})
  end

  test "health_check uses /api/health" do
    assert {:ok, %{"status" => "UP"}} = FitnessClient.health_check()
    assert_received {:health_request, headers}
    assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer stub-token"}]
  end

  test "get_diary uses /api/exercises/diary/:date" do
    assert {:ok, %{"entries" => []}} = FitnessClient.get_diary("2026-05-22")
    assert_received {:diary_request, headers}
    assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer stub-token"}]
  end

  test "get_exercises uses /api/exercises" do
    assert {:ok, [%{"id" => 1, "name" => "Bench Press"}]} = FitnessClient.get_exercises()
    assert_received {:exercises_request, headers}
    assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer stub-token"}]
  end

  test "401 response retries with re-login" do
    Application.put_env(:fittrack, Fittrack.FitnessClient, [
      base_url: "http://127.0.0.1:3010",
      email: "test@example.com",
      password: "password",
      http_client: HttpClientRetryStub
    ])

    FitnessClient.init_token_cache()
    Agent.update(Fittrack.FitnessClient.TokenCache, fn _ -> nil end)
    Process.delete(:exercise_request_count)

    assert {:ok, [%{"id" => 2, "name" => "Squat"}]} = FitnessClient.get_exercises()
    assert_received {:exercise_request_after_retry, headers}
    assert headers == [{"Content-Type", "application/json"}, {"Authorization", "Bearer retry-token"}]
    assert_received {:login_request, _body, _headers}
  end

  test "returns error tuple on 500 response" do
    Application.put_env(:fittrack, Fittrack.FitnessClient, [
      base_url: "http://127.0.0.1:3010",
      email: "test@example.com",
      password: "password",
      http_client: HttpClientErrorStub
    ])

    FitnessClient.init_token_cache()
    Agent.update(Fittrack.FitnessClient.TokenCache, fn _ -> nil end)

    assert {:error, message} = FitnessClient.get_exercises()
    assert message =~ "HTTP 500"
    assert message =~ "Server error"
    assert_received {:login_request, _body, _headers}
  end
end
