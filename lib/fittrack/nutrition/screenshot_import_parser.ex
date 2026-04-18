defmodule Fittrack.Nutrition.ScreenshotImportParser do
  @moduledoc """
  Parses uploaded or pasted nutrition screenshots into normalized food attrs.
  """

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.OpenAIImageParserClient

  def parse_image_data(data_url) when is_binary(data_url) do
    with true <- String.starts_with?(data_url, "data:image/") || {:error, :invalid_image},
         {:ok, attrs} <- parser_client().parse_image_data(data_url) do
      {:ok, Nutrition.barcode_food_defaults(attrs)}
    end
  end

  def parse_image_data(_), do: {:error, :invalid_image}

  defp parser_client do
    Application.get_env(:fittrack, :screenshot_import_parser_client, OpenAIImageParserClient)
  end
end
