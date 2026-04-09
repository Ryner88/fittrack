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
      exercise = exercise_fixture(scope)
      assert Training.list_exercises(scope) == [exercise]
    end

    test "get_exercise!/2 returns the exercise with given id", %{scope: scope} do
      exercise = exercise_fixture(scope)
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
      exercise = exercise_fixture(scope)

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
      exercise = exercise_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Training.update_exercise(scope, exercise, @invalid_attrs)

      assert exercise == Training.get_exercise!(scope, exercise.id)
    end

    test "delete_exercise/2 deletes the exercise", %{scope: scope} do
      exercise = exercise_fixture(scope)
      assert {:ok, %Exercise{}} = Training.delete_exercise(scope, exercise)
      assert_raise Ecto.NoResultsError, fn -> Training.get_exercise!(scope, exercise.id) end
    end

    test "change_exercise/1 returns a exercise changeset" do
      exercise = exercise_fixture()
      assert %Ecto.Changeset{} = Training.change_exercise(exercise)
    end

    test "get_exercise/2 returns the exercise when found", %{scope: scope} do
      exercise = exercise_fixture(scope)
      assert Training.get_exercise(scope, exercise.id) == exercise
    end

    test "log_exercise_set/2 creates a workout set entry", %{scope: scope} do
      exercise = exercise_fixture(scope)

      {:ok, _set} =
        Training.log_exercise_set(scope, %{
          "exercise_id" => exercise.id,
          "weight" => "100",
          "reps" => "5"
        })

      result =
        Fittrack.Repo.get_by(Fittrack.Training.WorkoutSet, exercise_id: exercise.id, reps: 5)

      assert result
      assert Decimal.equal?(result.weight, Decimal.new("100"))
    end

    test "exercise_progress_over_time/3 returns data points for logged sets", %{scope: scope} do
      exercise = exercise_fixture(scope)

      {:ok, _set} =
        Training.log_exercise_set(scope, %{
          "exercise_id" => exercise.id,
          "weight" => "105",
          "reps" => "8"
        })

      data = Training.exercise_progress_over_time(scope, exercise.id, 7)
      assert [%{avg_weight: _}] = data
    end

    test "workout_dates_in_month_with_counts returns day counts", %{scope: scope} do
      {:ok, workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.utc_now(),
          finished_at: DateTime.utc_now()
        })

      _ =
        Training.create_workout_set(scope, workout, %{
          exercise_id: exercise_fixture(scope).id,
          weight: "100",
          reps: "5"
        })

      start_date = Date.utc_today() |> Date.beginning_of_month()
      end_date = Date.utc_today() |> Date.end_of_month()

      data = Training.workout_dates_in_month_with_counts(scope, start_date, end_date)
      assert is_list(data)
    end

    test "log_exercise_set/2 rejects unauthorized exercise", %{scope: scope} do
      assert {:error, :unauthorized} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => 999_999,
                 "weight" => "100",
                 "reps" => "5"
               })
    end

    test "generate_ai_workout_plan/2 generates and saves workflow plan", %{scope: scope} do
      exercise_fixture(scope)

      params = %{
        "primary_goal" => "hypertrophy",
        "secondary_goal" => "strength",
        "training_styles" => ["hypertrophy", "mobility"],
        "training_split" => ["full_body", "hybrid"],
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3"
      }

      assert {:ok, plan} = Training.generate_ai_workout_plan(scope, params)
      assert plan.name =~ "AI Workout Plan"
      assert plan.goal == "hypertrophy"
      assert plan.primary_goal == "hypertrophy"
      assert plan.secondary_goal == "strength"
      assert plan.training_styles == ["hypertrophy", "mobility"]
      assert plan.training_split == ["full_body", "hybrid"]
      assert plan.difficulty == "beginner"
      assert length(plan.workout_plan_exercises) > 0
    end

    test "generate_ai_workout_plan/2 rejects duplicate goals", %{scope: scope} do
      exercise_fixture(scope)

      params = %{
        "primary_goal" => "strength",
        "secondary_goal" => "strength",
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3"
      }

      assert {:error, "Each goal must be unique."} =
               Training.generate_ai_workout_plan(scope, params)
    end
  end
end
