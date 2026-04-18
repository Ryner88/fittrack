defmodule Fittrack.ScreenshotImportParserClientStub do
  def parse_image_data(_data_url) do
    Application.fetch_env!(:fittrack, :screenshot_import_test_response)
  end
end
