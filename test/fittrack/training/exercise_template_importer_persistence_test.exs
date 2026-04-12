defmodule Fittrack.Training.ExerciseTemplateImporterPersistenceTest do
  use Fittrack.DataCase, async: true

  alias Fittrack.Repo
  alias Fittrack.Training.ExerciseTemplate
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
                 notes: "Original notes"
               })

      assert {:ok, :updated, updated_template} =
               ExerciseTemplateImporter.upsert_template(%{
                 source_id: 1001,
                 name: "Push-up",
                 primary_muscle: "Chest",
                 equipment: "Bodyweight",
                 notes: "Updated notes"
               })

      assert updated_template.id == template.id
      assert updated_template.notes == "Updated notes"
      assert Repo.aggregate(ExerciseTemplate, :count, :id) == initial_count + 1
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
  end
end
