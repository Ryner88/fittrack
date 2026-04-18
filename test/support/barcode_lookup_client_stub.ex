defmodule Fittrack.BarcodeLookupClientStub do
  def get(_url, _opts) do
    Application.fetch_env!(:fittrack, :barcode_lookup_test_response)
  end
end
