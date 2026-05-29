defmodule Fittrack.Training.OpenAIWorkoutParserClient do
  @moduledoc false

  @endpoint "https://api.openai.com/v1/chat/completions"

  def configured? do
    match?({:ok, _api_key}, fetch_api_key())
  end

  def parse_workout_text(text, context \\ %{})

  def parse_workout_text(text, context) when is_binary(text) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, body} <- request_openai(api_key, text, context),
         {:ok, attrs} <- decode_response(body) do
      {:ok, attrs}
    end
  end

  def parse_workout_text(_, _), do: {:error, :invalid_source}

  defp fetch_api_key do
    api_key = Application.get_env(:fittrack, :openai_api_key) || System.get_env("OPENAI_API_KEY")

    if is_binary(api_key) and api_key != "" do
      {:ok, api_key}
    else
      {:error, :not_configured}
    end
  end

  defp request_openai(api_key, text, context) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    payload = %{
      model: Application.get_env(:fittrack, :ai_workout_parser_model, "gpt-4.1-mini"),
      messages: [
        %{
          role: "system",
          content:
            "Convert workout articles, video descriptions, or training guides into FitTrack workout JSON. Return only valid JSON. Do not copy unsafe programming blindly. Cap unrealistic volume, avoid max-effort failure on complex lifts, and preserve uncertainty in notes. Schema: title string, summary string, safety_notes array of strings, exercises array. Each exercise must include name, scheduled_day, target_sets, target_reps_min, target_reps_max, rest_seconds, target_kind, notes. target_kind must be one of straight_set, superset, circuit, drop_set, amrap, timed_set, warm_up, failure, rest_pause, working_set, normal."
        },
        %{
          role: "user",
          content:
            "Context: #{Jason.encode!(context)}\n\nSource text:\n#{String.slice(text, 0, 12_000)}"
        }
      ],
      response_format: %{type: "json_object"}
    }

    case Req.post(@endpoint, headers: headers, json: payload) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: _status}} -> {:error, :parse_failed}
      {:error, _error} -> {:error, :parse_failed}
    end
  end

  defp decode_response(body) do
    with [%{"message" => %{"content" => content}} | _] <- body["choices"],
         {:ok, attrs} <- Jason.decode(content) do
      {:ok, attrs}
    else
      _ -> {:error, :parse_failed}
    end
  end
end
