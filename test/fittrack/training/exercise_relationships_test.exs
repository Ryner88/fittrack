defmodule Fittrack.Training.ExerciseRelationshipsTest do
  use Fittrack.DataCase, async: true

  alias Fittrack.Accounts.Scope
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
               Training.create_exercise_variation(bench, incline, %{
                 relationship: "angle",
                 similarity_score: 88,
                 equipment_requirements: ["Incline bench", "Incline bench", " "],
                 difficulty_delta: 1
               })

      assert variation.base_exercise_template_id == bench.id
      assert variation.variation_exercise_template_id == incline.id
      assert variation.similarity_score == 88
      assert variation.equipment_requirements == ["Incline bench"]
      assert variation.difficulty_delta == 1

      assert {:ok, substitution} =
               Training.create_exercise_substitution(bench, push_up, %{
                 reason: "home_training",
                 priority: 1,
                 similarity_score: 92,
                 equipment_requirements: ["Bodyweight"],
                 difficulty_delta: -1,
                 reason_quality: 85
               })

      assert substitution.exercise_template_id == bench.id
      assert substitution.substitute_exercise_template_id == push_up.id
      assert substitution.similarity_score == 92
      assert substitution.equipment_requirements == ["Bodyweight"]
      assert substitution.difficulty_delta == -1
      assert substitution.reason_quality == 85
    end

    test "validates metadata bounds" do
      bench = template_fixture("Bench Press", "Barbell")
      push_up = template_fixture("Push-Up", "Bodyweight")

      assert {:error, changeset} =
               Training.create_exercise_substitution(bench, push_up, %{
                 reason: "home_training",
                 similarity_score: 101,
                 reason_quality: -1,
                 difficulty_delta: 6
               })

      assert "must be less than or equal to 100" in errors_on(changeset).similarity_score
      assert "must be greater than or equal to 0" in errors_on(changeset).reason_quality
      assert "must be less than or equal to 5" in errors_on(changeset).difficulty_delta
    end

    test "substitution suggestions prefer relationship metadata before priority" do
      user = Fittrack.AccountsFixtures.user_fixture()
      scope = %Scope{user: user}
      bench = template_fixture("Bench Press", "Barbell")
      low_priority = template_fixture("Low Priority Push-Up", "Bodyweight")
      best_match = template_fixture("Best Match Press", "Dumbbell")

      assert {:ok, _exercise} = Training.add_template_to_user(scope, bench.id)

      assert {:ok, _substitution} =
               Training.create_exercise_substitution(bench, low_priority, %{
                 reason: "home_training",
                 priority: 0,
                 similarity_score: 30,
                 reason_quality: 30
               })

      assert {:ok, _substitution} =
               Training.create_exercise_substitution(bench, best_match, %{
                 reason: "equipment",
                 priority: 9,
                 similarity_score: 95,
                 reason_quality: 90
               })

      exercise = scope |> Training.list_exercises() |> List.first()

      assert [suggestion | _] =
               Training.list_substitution_suggestions_for_exercise(scope, exercise.id)

      assert suggestion.substitute_exercise_template_id == best_match.id
      assert suggestion.similarity_score == 95
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
