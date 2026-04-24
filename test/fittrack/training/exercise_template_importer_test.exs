defmodule Fittrack.Training.ExerciseTemplateImporterTest do
  use ExUnit.Case, async: true

  alias Fittrack.Training.ExerciseTemplateImporter

  defmodule WgerHttpClientStub do
    def get(url, headers: headers) do
      send(self(), {:wger_request, url, headers})

      case url do
        "https://wger.de/api/v2/exerciseinfo/" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "results" => [
                 %{"id" => 1, "name" => "Exercise 1"},
                 %{"id" => 2, "name" => "Exercise 2"}
               ],
               "next" => "https://wger.de/api/v2/exerciseinfo/?page=2"
             }
           }}

        "https://wger.de/api/v2/exerciseinfo/?page=2" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "results" => [
                 %{"id" => 3, "name" => "Exercise 3"},
                 %{"id" => 4, "name" => "Exercise 4"}
               ],
               "next" => nil
             }
           }}
      end
    end
  end

  defmodule InvalidWgerHttpClientStub do
    def get(_url, headers: _headers) do
      {:ok, %{status: 200, body: %{"count" => 1, "next" => nil}}}
    end
  end

  describe "fetch_exercises_from_wger/3" do
    test "follows pagination until the requested limit is reached" do
      assert {:ok, exercises} =
               ExerciseTemplateImporter.fetch_exercises_from_wger(
                 nil,
                 3,
                 WgerHttpClientStub
               )

      assert Enum.map(exercises, & &1["id"]) == [1, 2, 3]
      assert_received {:wger_request, "https://wger.de/api/v2/exerciseinfo/", []}
      assert_received {:wger_request, "https://wger.de/api/v2/exerciseinfo/?page=2", []}
    end

    test "includes the token header only when an api key is provided" do
      assert {:ok, [_exercise]} =
               ExerciseTemplateImporter.fetch_exercises_from_wger(
                 "secret-token",
                 1,
                 WgerHttpClientStub
               )

      assert_received {:wger_request, "https://wger.de/api/v2/exerciseinfo/",
                       [
                         {"Authorization", "Token secret-token"}
                       ]}
    end

    test "returns an error when the response body does not contain a result list" do
      assert {:error, message} =
               ExerciseTemplateImporter.fetch_exercises_from_wger(
                 nil,
                 5,
                 InvalidWgerHttpClientStub
               )

      assert message =~ "Unexpected WGER response shape"
    end
  end

  describe "normalize_exercise_from_wger/1" do
    test "prefers the English translation instead of the first translation" do
      exercise = %{
        "name" => "Base name",
        "description" => "Base description",
        "translations" => [
          %{
            "language" => "de",
            "name" => "Liegestutz",
            "description" => "Deutsche Beschreibung"
          },
          %{
            "language" => "en",
            "name" => "Push-up",
            "description" => "English description"
          }
        ],
        "muscles" => [%{"name" => "Pectorals"}],
        "equipment" => [%{"name" => "body weight"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.source_id == nil
      assert normalized.name == "Push-up"
      assert normalized.notes == "English description"
    end

    test "falls back to the first translation when English is missing" do
      exercise = %{
        "name" => "Base name",
        "description" => "Base description",
        "translations" => [
          %{
            "language" => "de",
            "name" => "Kniebeuge",
            "description" => "Deutsche Beschreibung"
          },
          %{
            "language" => "fr",
            "name" => "Squat FR",
            "description" => "Description francaise"
          }
        ],
        "muscles" => [%{"name" => "Quadriceps"}],
        "equipment" => [%{"name" => "barbell"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.name == "Kniebeuge"
      assert normalized.notes == "Deutsche Beschreibung"
    end

    test "detects English when the translation language is a nested map" do
      exercise = %{
        "name" => "Base name",
        "description" => "Base description",
        "translations" => [
          %{
            "language" => %{"short_name" => "en", "full_name" => "English"},
            "name" => "Deadlift",
            "description" => "English description"
          }
        ],
        "muscles" => [%{"name" => "Hamstrings"}],
        "equipment" => [%{"name" => "barbell"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.name == "Deadlift"
      assert normalized.notes == "English description"
    end

    test "stores descriptions as plain text instead of HTML" do
      exercise = %{
        "id" => 42,
        "name" => "Base name",
        "translations" => [
          %{
            "language" => "en",
            "name" => "Lunge",
            "description" =>
              "<p>Step&nbsp;forward</p><ol><li>Keep chest up</li><li>Drive back</li></ol>"
          }
        ],
        "muscles" => [%{"name" => "Quadriceps"}],
        "equipment" => [%{"name" => "body weight"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.source_id == 42
      assert normalized.name == "Lunge"
      assert normalized.notes == "Step forward - Keep chest up - Drive back"
      refute normalized.notes =~ ~r/<[^>]+>/
      refute normalized.notes =~ "&nbsp;"
    end

    test "prefers an English field value without mixing in a non-English root description" do
      exercise = %{
        "name" => "Bear Walk",
        "description" => "Deutsche Beschreibung auf Root-Ebene",
        "translations" => [
          %{
            "language" => "de",
            "name" => "Bear Walk DE",
            "description" => "German translation description"
          },
          %{
            "language" => "en",
            "name" => "Bear Walk",
            "description" => nil
          }
        ],
        "muscles" => [%{"name" => "Pectorals"}],
        "equipment" => [%{"name" => "body weight"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.name == "Bear Walk"
      assert normalized.notes == "German translation description"
    end

    test "treats WGER numeric language id 2 as English" do
      exercise = %{
        "id" => 976,
        "name" => nil,
        "description" => nil,
        "translations" => [
          %{
            "id" => 2560,
            "language" => 4,
            "name" => "Abdominales en V con Balon Medicinal",
            "description" => "Descripcion en espanol"
          },
          %{
            "id" => 1286,
            "language" => 2,
            "name" => "Medicine ball booklet crunch",
            "description" =>
              "Using a medicine ball as an overload will make the exercise heavier."
          }
        ],
        "muscles" => [%{"name" => "Rectus abdominis"}],
        "equipment" => [%{"name" => "body weight"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.source_id == 976
      assert normalized.name == "Medicine ball booklet crunch"

      assert normalized.notes ==
               "Using a medicine ball as an overload will make the exercise heavier."
    end

    test "prefers muscle name_en from live WGER payloads when present" do
      exercise = %{
        "id" => 980,
        "translations" => [
          %{
            "language" => 2,
            "name" => "commando pull-ups",
            "description" =>
              "<p>variation of the pull-up exercise, it is performed with a grip of one hand supine and one hand prone,&nbsp;do not twist the torso</p>\n"
          }
        ],
        "muscles" => [
          %{"name" => "Anterior deltoid", "name_en" => "Shoulders"},
          %{"name" => "Biceps brachii", "name_en" => "Biceps"}
        ],
        "equipment" => [%{"id" => 6, "name" => "Pull-up bar"}]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.source_id == 980
      assert normalized.name == "commando pull-ups"
      assert normalized.primary_muscle == "Shoulders"
      assert normalized.equipment == "Pull-up bar"
      assert normalized.notes =~ "variation of the pull-up exercise"
      refute normalized.notes =~ "&nbsp;"
    end

    test "prefers the main WGER image URL" do
      exercise = %{
        "id" => 981,
        "translations" => [
          %{
            "language" => 2,
            "name" => "Push-up",
            "description" => "Bodyweight press."
          }
        ],
        "muscles" => [%{"name_en" => "Chest"}],
        "equipment" => [%{"name" => "body weight"}],
        "images" => [
          %{"image" => "https://wger.de/media/exercise-images/981/side.jpg", "is_main" => false},
          %{"image" => "https://wger.de/media/exercise-images/981/main.jpg", "is_main" => true}
        ]
      }

      normalized = ExerciseTemplateImporter.normalize_exercise_from_wger(exercise)

      assert normalized.image_url == "https://wger.de/media/exercise-images/981/main.jpg"
    end
  end

  describe "sanitize_notes/1" do
    test "returns nil for blank HTML content" do
      assert ExerciseTemplateImporter.sanitize_notes("<p>&nbsp;</p>") == nil
    end

    test "decodes named and numeric HTML entities" do
      assert ExerciseTemplateImporter.sanitize_notes("Tom &amp; Jerry &#39;test&#39; &#x26;") ==
               "Tom & Jerry 'test' &"
    end
  end
end
