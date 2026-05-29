defmodule Fittrack.Training.ExerciseRelationshipsTest do
  use Fittrack.DataCase, async: true

  alias Fittrack.Training
  alias Fittrack.Training.ExerciseTemplate

  describe "exercise variations and substitutions" do
    test "prevents self-referential relationships" do
      bench = template_fixture("Bench Press", "Barbell")

      assert {:error, variation_changeset} =
               Training.create_exercise_variation(bench, bench, %{relationship: "angle"})

      assert "must be different from base exercise" in errors_on(variation_changeset).variation_exercise_template_id

      assert {:error, substitution_changeset} =
               Training.create_exercise_substitution(bench, bench, %{reason: "equipment"})

      assert "must be different from exercise" in errors_on(substitution_changeset).substitute_exercise_template_id
    end

    test "creates valid variation and substitution links" do
      bench = template_fixture("Bench Press", "Barbell")
      incline = template_fixture("Incline Bench Press", "Barbell")
      push_up = template_fixture("Push-Up", "Bodyweight")

      assert {:ok, variation} =
               Training.create_exercise_variation(bench, incline, %{relationship: "angle"})

      assert variation.base_exercise_template_id == bench.id
      assert variation.variation_exercise_template_id == incline.id

      assert {:ok, substitution} =
               Training.create_exercise_substitution(bench, push_up, %{
                 reason: "home_training",
                 priority: 1
               })

      assert substitution.exercise_template_id == bench.id
      assert substitution.substitute_exercise_template_id == push_up.id
    end
  end

  defp template_fixture(name, equipment) do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: name,
        primary_muscle: "Chest",
        equipment: equipment
      })
      |> Fittrack.Repo.insert()

    template
  end
end
