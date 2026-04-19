defmodule Fittrack.Nutrition.OpenAIImageParserClient do
  @moduledoc false

  @endpoint "https://api.openai.com/v1/chat/completions"

  def configured? do
    match?({:ok, _api_key}, fetch_api_key())
  end

  def parse_image_data(data_url) when is_binary(data_url) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, body} <- request_openai(api_key, data_url),
         {:ok, attrs} <- decode_response(body) do
      {:ok, attrs}
    end
  end

  def parse_image_data(_), do: {:error, :invalid_image}

  defp fetch_api_key do
    api_key = Application.get_env(:fittrack, :openai_api_key) || System.get_env("OPENAI_API_KEY")

    if is_binary(api_key) and api_key != "" do
      {:ok, api_key}
    else
      {:error, :not_configured}
    end
  end

  defp request_openai(api_key, data_url) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    payload = %{
      model: Application.get_env(:fittrack, :screenshot_import_model, "gpt-4.1-mini"),
      messages: [
        %{
          role: "system",
          content:
            "Extract nutrition facts from meal or food screenshots. Screenshots may be standard nutrition labels or dining hall nutrition modals. Return only valid JSON with keys name, unit, unit_amount, quantity, calories_per_unit, protein_per_unit, carbs_per_unit, fats_per_unit, fiber_per_unit, sugar_per_unit, sodium_mg_per_unit, micronutrients, and extraction. micronutrients should be an object of label to value strings. extraction should contain screen_type, venue_name, serving_size_text, extracted_text, detected_context, and field_mapping. field_mapping should map each normalized field name to the exact text you used. Use 0 for missing numeric values, an empty object for missing micronutrients, and an empty array for missing extracted_text."
        },
        %{
          role: "user",
          content: [
            %{
              type: "text",
              text:
                "Read this nutrition screenshot and extract a best-effort structured nutrition label. If serving size is shown, use that as both unit_amount and quantity. If the label is clearly per serving, set unit to serving. Support dining hall modal screenshots where calories and macros are shown in rows rather than a packaged-food label. Include the raw extracted text lines and a field mapping for every value you populate."
            },
            %{type: "image_url", image_url: %{url: data_url}}
          ]
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
