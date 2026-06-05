defmodule Fittrack.Training.ExerciseMediaCacheTest do
  use ExUnit.Case

  alias Fittrack.Training.ExerciseMediaCache

  defmodule HttpStub do
    def get("https://example.com/cache.jpg", _opts) do
      {:ok,
       %{
         status: 200,
         body: "cached-image",
         headers: [{"content-type", "image/jpeg"}, {"content-length", "12"}]
       }}
    end
  end

  test "caches valid media locally with checksum and metadata" do
    root =
      Path.join(System.tmp_dir!(), "fittrack-cache-test-#{System.unique_integer([:positive])}")

    assert {:ok, result} =
             ExerciseMediaCache.cache(
               %{exercise_template_id: 123, source_url: "https://example.com/cache.jpg"},
               http_client: HttpStub,
               storage_root: root
             )

    assert result.content_type == "image/jpeg"
    assert result.file_size == 12
    assert result.checksum == :crypto.hash(:sha256, "cached-image") |> Base.encode16(case: :lower)
    assert File.read!(Path.join(root, result.local_path)) == "cached-image"
  end
end
