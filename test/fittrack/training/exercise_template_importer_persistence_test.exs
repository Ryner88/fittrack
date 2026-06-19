defmodule Fittrack.Training.ExerciseTemplateImporterPersistenceTest do
  use Fittrack.DataCase, async: true

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseAlias
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource
  alias Fittrack.Training.ExerciseTemplateImporter

  describe "upsert_template/1" do
    test "updates an existing template when the same source_id is re-imported" do
      initial_count = Repo.aggregate(ExerciseTemplate, :count, :id)

      assert {:ok, :inserted, template} =
               ExerciseTemplateImporter.upsert_template(%{
                 source_id: 1001,
                 name: "Push-up",
                 primary_muscle: "Chest",
                 equipment: "Bodyweight",
                 image_url: "https://wger.de/media/exercise-images/1001/original.jpg",
                 notes: "Original notes"
               })

      assert {:ok, :updated, updated_template} =
               ExerciseTemplateImporter.upsert_template(%{
                 source_id: 1001,
                 name: "Push-up",
                 primary_muscle: "Chest",
                 equipment: "Bodyweight",
                 image_url: "https://wger.de/media/exercise-images/1001/updated.jpg",
                 notes: "Updated notes"
               })

      assert updated_template.id == template.id

      assert updated_template.image_url ==
               "https://wger.de/media/exercise-images/1001/updated.jpg"

      assert updated_template.notes == "Updated notes"
      assert Repo.aggregate(ExerciseTemplate, :count, :id) == initial_count + 1
    end

    test "persists normalized muscles equipment media and source metadata" do
      attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => 7007,
          "translations" => [
            %{
              "language" => 2,
              "name" => "Incline dumbbell press",
              "description" => "<p>Press with control.</p>"
            }
          ],
          "muscles" => [
            %{"name_en" => "Chest"},
            %{"name_en" => "Shoulders"},
            %{"name_en" => "Triceps"}
          ],
          "equipment" => [%{"name" => "Dumbbell"}, %{"name" => "Bench"}],
          "images" => [
            %{
              "id" => 9001,
              "image" => "https://wger.de/media/exercise-images/7007/main.jpg",
              "is_main" => true,
              "license_author" => "wger"
            }
          ]
        })

      assert {:ok, :inserted, template} = ExerciseTemplateImporter.upsert_template(attrs)

      assert Repo.get_by!(ExerciseTemplateSource, source: "wger", external_id: "7007")
      assert Repo.get_by!(ExerciseMuscle, normalized_name: "chest")
      assert Repo.get_by!(ExerciseMuscle, normalized_name: "shoulders")
      assert Repo.get_by!(ExerciseEquipment, normalized_name: "dumbbell")
      assert Repo.get_by!(ExerciseEquipment, normalized_name: "bench")

      assert Repo.aggregate(ExerciseTemplateMuscle, :count, :id) == 3
      assert Repo.aggregate(ExerciseTemplateEquipment, :count, :id) == 2

      media = Repo.get_by!(ExerciseMedia, source: "wger", source_id: "9001")
      assert media.exercise_template_id == template.id
      assert media.is_primary
      assert media.source_url == "https://wger.de/media/exercise-images/7007/main.jpg"
      assert media.provider_attribution == "wger"
      assert media.cache_status == "remote_only"
      assert media.metadata == %{"license_author" => "wger"}
    end

    test "persists canonical slugs aliases quality flags and searchable tags" do
      attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => 7107,
          "translations" => [
            %{
              "language" => 2,
              "name" => "Bench Press",
              "description" => "<p>Press from a flat bench.</p>"
            }
          ],
          "muscles" => [%{"name_en" => "Chest"}, %{"name_en" => "Triceps"}],
          "equipment" => [%{"name" => "Barbell"}]
        })

      assert {:ok, :inserted, template} = ExerciseTemplateImporter.upsert_template(attrs)

      template = Repo.reload!(template)
      assert template.slug == "bench-press"
      assert template.canonical_slug == "barbell-bench-press"

      assert template.weighted_tags == [
               "bench press",
               "bench-press",
               "chest",
               "triceps",
               "barbell"
             ]

      assert template.quality_score > 0
      refute template.is_verified
      refute template.is_ai_generated
      refute template.is_deprecated

      alias_names =
        ExerciseAlias
        |> Repo.all()
        |> Enum.map(& &1.name)

      assert "Bench Press" in alias_names
      assert "Barbell Bench Press" in alias_names
      assert "BB Bench Press" in alias_names

      assert [result] = Training.search_exercise_templates("BB Bench", limit: 5)
      assert result.id == template.id
    end

    test "adopts a legacy template without source_id when the normalized identity matches" do
      initial_count = Repo.aggregate(ExerciseTemplate, :count, :id)

      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "Push-up",
          primary_muscle: "Chest",
          equipment: "Bodyweight",
          notes: "Legacy notes"
        })
        |> Repo.insert()

      assert is_nil(template.source_id)

      assert {:ok, :updated, updated_template} =
               ExerciseTemplateImporter.upsert_template(%{
                 source_id: 2002,
                 name: "Push-up",
                 primary_muscle: "Chest",
                 equipment: "Bodyweight",
                 notes: "Fresh notes"
               })

      assert updated_template.id == template.id
      assert updated_template.source_id == 2002
      assert updated_template.notes == "Fresh notes"
      assert Repo.aggregate(ExerciseTemplate, :count, :id) == initial_count + 1
    end

    test "does not adopt a legacy template when the primary muscle differs" do
      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "Push-up",
          primary_muscle: "Triceps",
          equipment: "Bodyweight",
          notes: "Legacy notes"
        })
        |> Repo.insert()

      assert is_nil(template.source_id)

      assert {:error, changeset} =
               ExerciseTemplateImporter.upsert_template(%{
                 source_id: 3003,
                 name: "Push-up",
                 primary_muscle: "Chest",
                 equipment: "Bodyweight",
                 notes: "Fresh notes"
               })

      assert {"cannot safely adopt an existing legacy template for this source; resolve the legacy template manually",
              _opts} =
               changeset.errors[:source_id]

      reloaded = Repo.get!(ExerciseTemplate, template.id)
      assert is_nil(reloaded.source_id)
      assert reloaded.notes == "Legacy notes"
    end

    test "adopts a legacy template from a production-like WGER payload using muscle name_en" do
      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "commando pull-ups",
          primary_muscle: "Shoulders",
          equipment: "Pull-up bar",
          notes: "Legacy notes"
        })
        |> Repo.insert()

      attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => 4004,
          "translations" => [
            %{
              "language" => 2,
              "name" => "commando pull-ups",
              "description" => "<p>Fresh notes</p>"
            }
          ],
          "muscles" => [
            %{"name" => "Anterior deltoid", "name_en" => "Shoulders"}
          ],
          "equipment" => [%{"name" => "Pull-up bar"}]
        })

      assert {:ok, :updated, updated_template} = ExerciseTemplateImporter.upsert_template(attrs)

      assert updated_template.id == template.id
      assert updated_template.source_id == 4004
      assert updated_template.primary_muscle == "Shoulders"
      assert updated_template.notes == "Fresh notes"
    end
  end

  describe "refresh_existing_templates/2" do
    test "updates matching templates and skips unmatched WGER records" do
      source_id = unique_source_id()
      unmatched_source_id = unique_source_id()
      image_id = "refresh-image-#{source_id}"

      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "Cable Row",
          primary_muscle: "Back",
          equipment: "Cable",
          notes: "Legacy notes"
        })
        |> Repo.insert()

      matching_attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => source_id,
          "translations" => [
            %{
              "language" => 2,
              "name" => "Cable Row",
              "description" => "Fresh row notes."
            }
          ],
          "muscles" => [%{"name_en" => "Back"}],
          "equipment" => [%{"name" => "Cable"}],
          "images" => [
            %{
              "id" => image_id,
              "image" => "https://wger.de/media/exercise-images/#{source_id}/main.jpg",
              "is_main" => true,
              "license_author" => "wger"
            }
          ]
        })

      unmatched_attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => unmatched_source_id,
          "translations" => [
            %{"language" => 2, "name" => "Unmatched Jump", "description" => "Skip me."}
          ],
          "muscles" => [%{"name_en" => "Quads"}],
          "equipment" => [%{"name" => "body weight"}]
        })

      result =
        ExerciseTemplateImporter.refresh_existing_templates([matching_attrs, unmatched_attrs])

      assert result.matched == 1
      assert result.updated == 1
      assert result.skipped == 1
      assert result.failed == 0
      assert result.failures == []

      reloaded = Repo.get!(ExerciseTemplate, template.id)
      assert reloaded.source_id == source_id
      assert reloaded.notes == "Fresh row notes."

      media = Repo.get_by!(ExerciseMedia, source: "wger", source_id: image_id)
      assert media.exercise_template_id == template.id
      assert media.cache_status == "remote_only"
      assert media.source_url == "https://wger.de/media/exercise-images/#{source_id}/main.jpg"

      refute Repo.get_by(ExerciseTemplate, source_id: unmatched_source_id)
    end

    test "dry run reports matches without writing template or media changes" do
      source_id = unique_source_id()

      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          source_id: source_id,
          name: "Dry Run Row",
          primary_muscle: "Back",
          equipment: "Cable",
          notes: "Original notes"
        })
        |> Repo.insert()

      attrs =
        ExerciseTemplateImporter.normalize_exercise_from_wger(%{
          "id" => source_id,
          "translations" => [
            %{"language" => 2, "name" => "Dry Run Row", "description" => "Fresh notes."}
          ],
          "muscles" => [%{"name_en" => "Back"}],
          "equipment" => [%{"name" => "Cable"}],
          "images" => [
            %{
              "id" => "dry-run-image-#{source_id}",
              "image" => "https://wger.de/media/exercise-images/#{source_id}/main.jpg",
              "is_main" => true
            }
          ]
        })

      result = ExerciseTemplateImporter.refresh_existing_templates([attrs], dry_run: true)

      assert result.matched == 1
      assert result.updated == 0
      assert result.skipped == 0
      assert result.failed == 0

      reloaded = Repo.get!(ExerciseTemplate, template.id)
      assert reloaded.notes == "Original notes"
      refute Repo.get_by(ExerciseMedia, source: "wger", source_id: "dry-run-image-#{source_id}")
    end
  end

  describe "insert_templates/1" do
    test "returns detailed failure metadata while keeping successful records" do
      result =
        ExerciseTemplateImporter.insert_templates([
          %{
            source_id: 5005,
            name: "Cable Row",
            primary_muscle: "Back",
            equipment: "Cable",
            notes: "Good record"
          },
          %{
            source_id: 5006,
            name: nil,
            primary_muscle: "Back",
            equipment: "Cable",
            notes: "Missing name"
          }
        ])

      assert result.inserted == 1
      assert result.updated == 0
      assert result.failed == 1

      assert [
               %{
                 source_id: 5006,
                 name: nil,
                 errors: %{name: "can't be blank"}
               }
             ] = result.failures

      assert Repo.get_by!(ExerciseTemplate, source_id: 5005).name == "Cable Row"
    end
  end

  test "reimporting WGER metadata preserves cached media fields" do
    source_id = unique_source_id()
    image_id = "cached-image-#{source_id}"

    attrs =
      ExerciseTemplateImporter.normalize_exercise_from_wger(%{
        "id" => source_id,
        "translations" => [
          %{"language" => 2, "name" => "Cached Media Row", "description" => "Original."}
        ],
        "muscles" => [%{"name_en" => "Chest"}],
        "equipment" => [%{"name" => "Dumbbell"}],
        "images" => [
          %{
            "id" => image_id,
            "image" => "https://wger.de/media/exercise-images/#{source_id}/main.jpg",
            "is_main" => true
          }
        ]
      })

    assert {:ok, :inserted, template} = ExerciseTemplateImporter.upsert_template(attrs)

    media = Repo.get_by!(ExerciseMedia, source: "wger", source_id: image_id)
    cached_at = DateTime.utc_now() |> DateTime.truncate(:second)

    assert {:ok, cached_media} =
             media
             |> ExerciseMedia.changeset(%{
               cache_status: "cached",
               local_path: "#{template.id}/main.jpg",
               storage_key: "#{template.id}/main.jpg",
               content_hash: "same-hash",
               cached_at: cached_at,
               mime_type: "image/jpeg",
               file_size: 123
             })
             |> Repo.update()

    assert {:ok, :updated, _template} =
             ExerciseTemplateImporter.upsert_template(%{attrs | notes: "Updated."})

    reloaded = Repo.reload!(cached_media)
    assert reloaded.cache_status == "cached"
    assert reloaded.local_path == "#{template.id}/main.jpg"
    assert reloaded.storage_key == "#{template.id}/main.jpg"
    assert reloaded.content_hash == "same-hash"
    assert reloaded.cached_at == cached_at
    assert reloaded.mime_type == "image/jpeg"
    assert reloaded.file_size == 123
  end

  defp unique_source_id do
    System.unique_integer([:positive]) + 900_000
  end
end
