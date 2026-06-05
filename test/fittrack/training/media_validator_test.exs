defmodule Fittrack.Training.MediaValidatorTest do
  use ExUnit.Case, async: true

  alias Fittrack.Training.MediaValidator

  defmodule HttpStub do
    def head("https://example.com/ok.jpg", _opts),
      do:
        {:ok, %{status: 200, headers: [{"content-type", "image/jpeg"}, {"content-length", "12"}]}}

    def head("https://example.com/missing.jpg", _opts), do: {:ok, %{status: 404, headers: []}}

    def head("https://example.com/page.html", _opts),
      do:
        {:ok, %{status: 200, headers: [{"content-type", "text/html"}, {"content-length", "12"}]}}

    def head("https://example.com/no-head.jpg", _opts), do: {:ok, %{status: 405, headers: []}}

    def get("https://example.com/no-head.jpg", _opts),
      do:
        {:ok,
         %{
           status: 200,
           body: "image-bytes",
           headers: [{"content-type", "image/png"}, {"content-length", "11"}]
         }}
  end

  test "rejects blank and non-http URLs" do
    assert {:error, :invalid_url} = MediaValidator.validate_url("", http_client: HttpStub)

    assert {:error, :invalid_url} =
             MediaValidator.validate_url("ftp://example.com/a.jpg", http_client: HttpStub)
  end

  test "accepts supported image metadata" do
    assert {:ok, %{content_type: "image/jpeg", content_length: 12, media_type: "image"}} =
             MediaValidator.validate_url("https://example.com/ok.jpg", http_client: HttpStub)
  end

  test "rejects stale and unsupported URLs" do
    assert {:error, :stale_url} =
             MediaValidator.validate_url("https://example.com/missing.jpg", http_client: HttpStub)

    assert {:error, :unsupported_content_type} =
             MediaValidator.validate_url("https://example.com/page.html", http_client: HttpStub)
  end

  test "falls back to GET when HEAD is unavailable" do
    assert {:ok, %{content_type: "image/png", content_length: 11}} =
             MediaValidator.validate_url("https://example.com/no-head.jpg", http_client: HttpStub)
  end
end
