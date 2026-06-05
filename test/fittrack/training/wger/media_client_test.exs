defmodule Fittrack.Training.Wger.MediaClientTest do
  use ExUnit.Case, async: true

  alias Fittrack.Training.Wger.MediaClient

  defmodule HttpStub do
    def get(url, _opts) do
      send(self(), {:wger_media_request, url})

      case url do
        "https://wger.de/api/v2/exerciseimage/" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "next" => "https://wger.de/api/v2/exerciseimage/?page=2",
               "results" => [
                 %{
                   "id" => 10,
                   "exercise" => 100,
                   "image" => "https://wger.de/media/100/main.jpg",
                   "is_main" => true,
                   "license_author" => "wger"
                 }
               ]
             }
           }}

        "https://wger.de/api/v2/exerciseimage/?page=2" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "next" => nil,
               "results" => [
                 %{
                   "id" => 11,
                   "exercise_base" => 100,
                   "image" => "https://wger.de/media/100/side.jpg"
                 }
               ]
             }
           }}
      end
    end
  end

  test "fetches paginated image media records and normalizes them" do
    assert {:ok, records} =
             MediaClient.fetch_media(limit: 2, media_type: "image", http_client: HttpStub)

    assert_received {:wger_media_request, "https://wger.de/api/v2/exerciseimage/"}
    assert_received {:wger_media_request, "https://wger.de/api/v2/exerciseimage/?page=2"}

    assert [
             %{
               kind: "image",
               source: "wger",
               source_id: "10",
               source_exercise_id: "100",
               source_url: "https://wger.de/media/100/main.jpg",
               is_primary: true
             },
             %{source_id: "11", source_exercise_id: "100"}
           ] = records
  end
end
