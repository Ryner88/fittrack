defmodule Fittrack.UrlImportHttpClientStub do
  def get(_url, _opts) do
    Application.fetch_env!(:fittrack, :url_import_test_response)
  end
end
