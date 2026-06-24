defmodule Fittrack.Training.ExerciseTaxonomyBackfillTest do
  use Fittrack.DataCase, async: true

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseMedia
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateEquipment
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.ExerciseTemplateSource
  alias Fittrack.Training.ExerciseTaxonomyBackfill

  test "backfills source and taxonomy joins from legacy template fields" do
    source_id = unique_source_id()

    template =
      template_fixture(%{
        source_id: source_id,
        name: "Legacy Taxonomy Row",
        primary_muscle: "Chest",
        secondary_muscles: ["Triceps"],
        equipment: "Cable"
      })

    media =
      media_fixture(template, %{
        cache_status: "cached",
        local_path: "#{template.id}/cached.jpg",
        storage_key: "#{template.id}/cached.jpg",
        content_hash: "same-hash",
        cached_at: ~U[2026-06-01 12:00:00Z],
        mime_type: "image/jpeg",
        file_size: 321
      })

    assert {:ok, report} = ExerciseTaxonomyBackfill.run(template_id: template.id)

    assert report.total_templates_inspected == 1
    assert report.templates_updated == 1
    assert report.sources_created == 1
    assert report.muscle_joins_created == 2
    assert report.equipment_joins_created == 1
    assert report.media_cached == 1
    assert report.media_missing == 0
    assert report.errors == 0

    assert Repo.get_by!(ExerciseTemplateSource, source: "wger", external_id: to_string(source_id))
    assert Repo.get_by!(ExerciseMuscle, normalized_name: "chest")
    assert Repo.get_by!(ExerciseMuscle, normalized_name: "triceps")
    assert Repo.get_by!(ExerciseEquipment, normalized_name: "cable")

    assert Repo.aggregate(ExerciseTemplateMuscle, :count, :id) == 2
    assert Repo.aggregate(ExerciseTemplateEquipment, :count, :id) == 1

    assert Repo.reload!(media).cache_status == "cached"
    assert Repo.reload!(media).local_path == "#{template.id}/cached.jpg"
  end

  test "uses stored WGER payload source metadata when available" do
    source_id = unique_source_id()

    template =
      template_fixture(%{
        name: "Payload Taxonomy Row",
        primary_muscle: nil,
        secondary_muscles: [],
        equipment: nil
      })

    source_fixture(template, %{
      source: "wger",
      external_id: to_string(source_id),
      source_url: nil,
      payload: %{
        "id" => source_id,
        "muscles" => [%{"id" => 4, "name_en" => "Pectorals"}],
        "muscles_secondary" => [%{"id" => 5, "name_en" => "Triceps"}],
        "equipment" => [%{"id" => 8, "name" => "Dumbbells"}]
      }
    })

    assert {:ok, report} = ExerciseTaxonomyBackfill.run(template_id: template.id)

    assert report.total_templates_inspected == 1
    assert report.templates_updated == 1
    assert report.muscles_created == 2
    assert report.muscle_joins_created == 2
    assert report.equipment_created == 1
    assert report.equipment_joins_created == 1
    assert report.source_links_updated == 1
    assert report.media_missing == 1
    assert report.errors == 0

    reloaded = Repo.reload!(template)
    assert reloaded.source_id == source_id
    assert reloaded.primary_muscle == "Chest"
    assert reloaded.secondary_muscles == ["Triceps"]
    assert reloaded.equipment == "Dumbbell"

    chest = Repo.get_by!(ExerciseMuscle, normalized_name: "chest")
    triceps = Repo.get_by!(ExerciseMuscle, normalized_name: "triceps")
    dumbbell = Repo.get_by!(ExerciseEquipment, normalized_name: "dumbbell")

    assert chest.source == "wger"
    assert chest.source_id == "4"
    assert triceps.source_id == "5"
    assert dumbbell.source == "wger"
    assert dumbbell.source_id == "8"

    source =
      Repo.get_by!(ExerciseTemplateSource, source: "wger", external_id: to_string(source_id))

    assert source.source_url == "https://wger.de/api/v2/exerciseinfo/#{source_id}/"
  end

  test "is idempotent and does not duplicate existing normalized records or joins" do
    source_id = unique_source_id()

    template =
      template_fixture(%{source_id: source_id, primary_muscle: "Back", equipment: "Cable"})

    assert {:ok, first_report} = ExerciseTaxonomyBackfill.run(template_id: template.id)
    assert first_report.templates_updated == 1

    assert {:ok, second_report} = ExerciseTaxonomyBackfill.run(template_id: template.id)

    assert second_report.templates_updated == 0
    assert second_report.muscles_created == 0
    assert second_report.muscle_joins_created == 0
    assert second_report.equipment_created == 0
    assert second_report.equipment_joins_created == 0
    assert second_report.sources_created == 0
    assert second_report.skipped_records == 1
    assert second_report.errors == 0

    assert Repo.aggregate(ExerciseTemplateSource, :count, :id) == 1
    assert Repo.aggregate(ExerciseMuscle, :count, :id) == 1
    assert Repo.aggregate(ExerciseTemplateMuscle, :count, :id) == 1
    assert Repo.aggregate(ExerciseEquipment, :count, :id) == 1
    assert Repo.aggregate(ExerciseTemplateEquipment, :count, :id) == 1
  end

  defp template_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          name: "Taxonomy Backfill Fixture #{System.unique_integer([:positive])}",
          primary_muscle: "Hamstrings",
          equipment: "Barbell",
          difficulty: "intermediate"
        },
        attrs
      )

    %ExerciseTemplate{}
    |> ExerciseTemplate.changeset(attrs)
    |> Repo.insert!()
  end

  defp source_fixture(template, attrs) do
    %ExerciseTemplateSource{}
    |> ExerciseTemplateSource.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          source: "wger",
          external_id: to_string(unique_source_id()),
          payload: %{}
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp media_fixture(template, attrs) do
    %ExerciseMedia{}
    |> ExerciseMedia.changeset(
      Map.merge(
        %{
          exercise_template_id: template.id,
          kind: "image",
          source: "wger",
          source_id: "media-#{System.unique_integer([:positive])}",
          source_exercise_id: to_string(template.source_id),
          source_url: "https://wger.de/media/#{template.id}.jpg",
          cache_status: "remote_only",
          is_primary: true
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp unique_source_id do
    System.unique_integer([:positive]) + 1_200_000
  end
end
