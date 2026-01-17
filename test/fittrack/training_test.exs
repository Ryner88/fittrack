defmodule Fittrack.TrainingTest do
  use Fittrack.DataCase

  alias Fittrack.Training

  describe "exercises" do
    alias Fittrack.Training.Exercise

    import Fittrack.TrainingFixtures

    @invalid_attrs %{name: nil, primary_muscle: nil, equipment: nil, notes: nil}

    test "list_exercises/0 returns all exercises" do
      exercise = exercise_fixture()
      assert Training.list_exercises() == [exercise]
    end

    test "get_exercise!/1 returns the exercise with given id" do
      exercise = exercise_fixture()
      assert Training.get_exercise!(exercise.id) == exercise
    end

    test "create_exercise/1 with valid data creates a exercise" do
      valid_attrs = %{
        name: "some name",
        primary_muscle: "some primary_muscle",
        equipment: "some equipment",
        notes: "some notes"
      }

      assert {:ok, %Exercise{} = exercise} = Training.create_exercise(valid_attrs)
      assert exercise.name == "some name"
      assert exercise.primary_muscle == "some primary_muscle"
      assert exercise.equipment == "some equipment"
      assert exercise.notes == "some notes"
    end

    test "create_exercise/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Training.create_exercise(@invalid_attrs)
    end

    test "update_exercise/2 with valid data updates the exercise" do
      exercise = exercise_fixture()

      update_attrs = %{
        name: "some updated name",
        primary_muscle: "some updated primary_muscle",
        equipment: "some updated equipment",
        notes: "some updated notes"
      }

      assert {:ok, %Exercise{} = exercise} = Training.update_exercise(exercise, update_attrs)
      assert exercise.name == "some updated name"
      assert exercise.primary_muscle == "some updated primary_muscle"
      assert exercise.equipment == "some updated equipment"
      assert exercise.notes == "some updated notes"
    end

    test "update_exercise/2 with invalid data returns error changeset" do
      exercise = exercise_fixture()
      assert {:error, %Ecto.Changeset{}} = Training.update_exercise(exercise, @invalid_attrs)
      assert exercise == Training.get_exercise!(exercise.id)
    end

    test "delete_exercise/1 deletes the exercise" do
      exercise = exercise_fixture()
      assert {:ok, %Exercise{}} = Training.delete_exercise(exercise)
      assert_raise Ecto.NoResultsError, fn -> Training.get_exercise!(exercise.id) end
    end

    test "change_exercise/1 returns a exercise changeset" do
      exercise = exercise_fixture()
      assert %Ecto.Changeset{} = Training.change_exercise(exercise)
    end
  end
end
