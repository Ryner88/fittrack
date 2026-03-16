defmodule Fittrack.TrainingTest do
  use Fittrack.DataCase

  alias Fittrack.Training

  describe "exercises" do
    alias Fittrack.Training.Exercise

    import Fittrack.TrainingFixtures
    import Fittrack.AccountsFixtures

    @invalid_attrs %{name: nil, primary_muscle: nil, equipment: nil, notes: nil}

    setup do
      %{scope: user_scope_fixture()}
    end

    test "list_exercises/1 returns all exercises for user", %{scope: scope} do
      exercise = exercise_fixture()
      assert Training.list_exercises(scope) == [exercise]
    end

    test "get_exercise!/2 returns the exercise with given id", %{scope: scope} do
      exercise = exercise_fixture()
      assert Training.get_exercise!(scope, exercise.id) == exercise
    end

    test "create_exercise/2 with valid data creates a exercise", %{scope: scope} do
      valid_attrs = %{
        name: "some name",
        primary_muscle: "some primary_muscle",
        equipment: "some equipment",
        notes: "some notes"
      }

      assert {:ok, %Exercise{} = exercise} = Training.create_exercise(scope, valid_attrs)
      assert exercise.name == "some name"
      assert exercise.primary_muscle == "some primary_muscle"
      assert exercise.equipment == "some equipment"
      assert exercise.notes == "some notes"
    end

    test "create_exercise/2 with invalid data returns error changeset", %{scope: scope} do
      assert {:error, %Ecto.Changeset{}} = Training.create_exercise(scope, @invalid_attrs)
    end

    test "update_exercise/3 with valid data updates the exercise", %{scope: scope} do
      exercise = exercise_fixture()

      update_attrs = %{
        name: "some updated name",
        primary_muscle: "some updated primary_muscle",
        equipment: "some updated equipment",
        notes: "some updated notes"
      }

      assert {:ok, %Exercise{} = exercise} =
               Training.update_exercise(scope, exercise, update_attrs)

      assert exercise.name == "some updated name"
      assert exercise.primary_muscle == "some updated primary_muscle"
      assert exercise.equipment == "some updated equipment"
      assert exercise.notes == "some updated notes"
    end

    test "update_exercise/3 with invalid data returns error changeset", %{scope: scope} do
      exercise = exercise_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Training.update_exercise(scope, exercise, @invalid_attrs)

      assert exercise == Training.get_exercise!(scope, exercise.id)
    end

    test "delete_exercise/2 deletes the exercise", %{scope: scope} do
      exercise = exercise_fixture()
      assert {:ok, %Exercise{}} = Training.delete_exercise(scope, exercise)
      assert_raise Ecto.NoResultsError, fn -> Training.get_exercise!(scope, exercise.id) end
    end

    test "change_exercise/1 returns a exercise changeset" do
      exercise = exercise_fixture()
      assert %Ecto.Changeset{} = Training.change_exercise(exercise)
    end
  end
end
