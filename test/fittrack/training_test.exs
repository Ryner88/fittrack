defmodule Fittrack.TrainingTest do
  use Fittrack.DataCase

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.Workout

  describe "exercises" do
    alias Fittrack.Training.Exercise
    alias Fittrack.Training.ExerciseTemplate

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

    test "create_exercise/2 keeps personal exercises private even when params request sharing", %{
      scope: scope
    } do
      attrs = %{
        name: "Shared Attempt",
        primary_muscle: "Chest",
        equipment: "Bodyweight",
        is_private: false
      }

      assert {:ok, %Exercise{} = exercise} = Training.create_exercise(scope, attrs)
      assert exercise.is_private
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

    test "update_exercise/3 does not publish personal exercises from params", %{scope: scope} do
      exercise = exercise_fixture(scope)

      assert {:ok, %Exercise{} = exercise} =
               Training.update_exercise(scope, exercise, %{is_private: false})

      assert exercise.is_private
    end

    test "personal exercise queries stay scoped to the owner" do
      owner_scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      exercise = exercise_fixture(owner_scope, %{name: "Private Trainer Draft"})

      assert Training.list_exercises(owner_scope) == [exercise]
      assert Training.list_exercises(other_scope) == []
      assert Training.get_exercise(other_scope, exercise.id) == nil
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

    test "add_template_to_user/2 links the exercise to the source template", %{scope: scope} do
      {:ok, template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          name: "Push-up",
          primary_muscle: "Chest",
          equipment: "Bodyweight",
          image_url: "https://wger.de/media/exercise-images/1001/main.jpg",
          notes: "Template notes"
        })
        |> Fittrack.Repo.insert()

      assert {:ok, exercise} = Training.add_template_to_user(scope, template.id)
      assert exercise.source_template_id == template.id

      reloaded = Training.get_exercise!(scope, exercise.id, preload_source_template: true)
      assert reloaded.source_template.image_url == template.image_url
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

    test "get_active_workout/1 returns active workouts by lifecycle state", %{scope: scope} do
      {:ok, completed_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        })

      {:ok, _set} =
        Training.create_workout_set(scope, completed_workout, %{
          exercise_id: exercise_fixture(scope).id,
          weight: "100",
          reps: "5",
          kind: "normal"
        })

      assert {:ok, completed_workout} = Training.complete_workout(scope, completed_workout)
      assert completed_workout.lifecycle_state == Workout.completed_state()

      {:ok, active_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.utc_now()
        })

      assert Training.get_active_workout(scope).id == active_workout.id
    end

    test "get_open_workout/1 returns draft and active workouts", %{scope: scope} do
      draft = draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

      assert Training.get_active_workout(scope) == nil
      assert Training.get_open_workout(scope).id == draft.id

      assert {:ok, active} = Training.start_workout(scope, draft)
      assert Training.get_active_workout(scope).id == active.id
      assert Training.get_open_workout(scope).id == active.id
    end

    test "create_workout/2 prevents a second active workout", %{scope: scope} do
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})

      assert workout.lifecycle_state == Workout.active_state()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Training.create_workout(scope, %{started_at: DateTime.utc_now()})

      assert "cannot start another workout while one is already open" in errors_on(changeset).started_at
    end

    test "create_workout/2 prevents a second open workout when a draft exists", %{scope: scope} do
      draft_started_at = DateTime.utc_now() |> DateTime.truncate(:second)

      %Workout{}
      |> Workout.lifecycle_changeset(%{
        started_at: draft_started_at,
        lifecycle_state: Workout.draft_state()
      })
      |> Ecto.Changeset.put_change(:user_id, scope.user.id)
      |> Repo.insert!()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Training.create_workout(scope, %{started_at: DateTime.utc_now()})

      assert "cannot start another workout while one is already open" in errors_on(changeset).started_at
    end

    test "workout lifecycle changeset maps open-workout constraint errors to started_at", %{
      scope: scope
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %Workout{}
      |> Workout.lifecycle_changeset(%{
        started_at: now,
        lifecycle_state: Workout.active_state()
      })
      |> Ecto.Changeset.put_change(:user_id, scope.user.id)
      |> Repo.insert!()

      assert {:error, %Ecto.Changeset{} = changeset} =
               %Workout{}
               |> Workout.lifecycle_changeset(%{
                 started_at: DateTime.add(now, 60, :second),
                 lifecycle_state: Workout.active_state()
               })
               |> Ecto.Changeset.put_change(:user_id, scope.user.id)
               |> Repo.insert()

      assert "cannot start another workout while one is already open" in errors_on(changeset).started_at
      refute Map.has_key?(errors_on(changeset), :user_id)
    end

    test "start_workout/3 activates a draft and replaces the shell timestamp", %{
      scope: scope
    } do
      old_started_at =
        DateTime.utc_now()
        |> DateTime.add(-7 * 24 * 60 * 60, :second)
        |> DateTime.truncate(:second)

      activation_started_at = DateTime.utc_now() |> DateTime.truncate(:second)
      draft = draft_workout_fixture(scope, old_started_at)

      assert {:ok, started} = Training.start_workout(scope, draft, activation_started_at)
      assert started.lifecycle_state == Workout.active_state()
      assert started.started_at == activation_started_at
      assert started.completed_at == nil
      assert started.discarded_at == nil

      assert {:ok, active_again} = Training.start_workout(scope, started)
      assert active_again.id == started.id
      assert active_again.started_at == activation_started_at
    end

    test "create_workout_set/3 starts a draft with a fresh activation timestamp", %{
      scope: scope
    } do
      old_started_at =
        DateTime.utc_now()
        |> DateTime.add(-7 * 24 * 60 * 60, :second)
        |> DateTime.truncate(:second)

      draft = draft_workout_fixture(scope, old_started_at)
      exercise = exercise_fixture(scope)

      assert {:ok, _set} =
               Training.create_workout_set(scope, draft, %{
                 exercise_id: exercise.id,
                 weight: "100",
                 reps: "5",
                 kind: "normal"
               })

      reloaded = Training.get_workout!(scope, draft.id)
      assert reloaded.lifecycle_state == Workout.active_state()
      assert DateTime.compare(reloaded.started_at, old_started_at) == :gt
    end

    test "create_workout_set/3 leaves drafts unchanged when validation fails", %{
      scope: scope
    } do
      old_started_at = DateTime.utc_now() |> DateTime.truncate(:second)
      draft = draft_workout_fixture(scope, old_started_at)
      exercise = exercise_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Training.create_workout_set(scope, draft, %{
                 exercise_id: exercise.id,
                 weight: "100",
                 reps: "0",
                 kind: "normal"
               })

      reloaded = Training.get_workout!(scope, draft.id)
      assert reloaded.lifecycle_state == Workout.draft_state()
      assert reloaded.started_at == old_started_at
      assert reloaded.workout_sets == []
    end

    test "create_workout_set/3 leaves drafts unchanged when exercise is invalid", %{
      scope: scope
    } do
      old_started_at = DateTime.utc_now() |> DateTime.truncate(:second)
      draft = draft_workout_fixture(scope, old_started_at)

      assert {:error, :invalid_exercise} =
               Training.create_workout_set(scope, draft, %{
                 exercise_id: 999_999,
                 weight: "100",
                 reps: "5",
                 kind: "normal"
               })

      reloaded = Training.get_workout!(scope, draft.id)
      assert reloaded.lifecycle_state == Workout.draft_state()
      assert reloaded.started_at == old_started_at
      assert reloaded.workout_sets == []
    end

    test "create_workout_set/3 returns workout_closed for terminal workouts", %{scope: scope} do
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      assert {:ok, completed} = Training.complete_workout(scope, workout)

      assert {:error, :workout_closed} =
               Training.create_workout_set(scope, completed, %{
                 exercise_id: exercise_fixture(scope).id,
                 weight: "100",
                 reps: "5",
                 kind: "normal"
               })
    end

    test "complete_workout/2, discard_workout/2, and start_workout/3 are scoped lifecycle operations",
         %{
           scope: scope
         } do
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      other_scope = user_scope_fixture()

      assert {:error, :unauthorized} = Training.complete_workout(other_scope, workout)
      assert {:error, :unauthorized} = Training.discard_workout(other_scope, workout)
      assert {:error, :unauthorized} = Training.start_workout(other_scope, workout)

      assert {:ok, completed} = Training.complete_workout(scope, workout)
      assert completed.lifecycle_state == Workout.completed_state()
      assert completed.completed_at
      assert {:ok, completed_again} = Training.complete_workout(scope, completed)
      assert completed_again.id == completed.id
      assert {:error, :invalid_transition} = Training.discard_workout(scope, completed)
      assert {:error, :invalid_transition} = Training.start_workout(scope, completed)

      {:ok, active} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      assert {:ok, discarded} = Training.discard_workout(scope, active)
      assert discarded.lifecycle_state == Workout.discarded_state()
      assert discarded.discarded_at
      assert {:ok, discarded_again} = Training.discard_workout(scope, discarded)
      assert discarded_again.id == discarded.id
      assert {:error, :invalid_transition} = Training.complete_workout(scope, discarded)
      assert {:error, :invalid_transition} = Training.start_workout(scope, discarded)
    end

    test "terminal transitions do not overwrite each other from stale structs", %{scope: scope} do
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      stale_workout = workout

      assert {:ok, completed} = Training.complete_workout(scope, workout)
      assert completed.lifecycle_state == Workout.completed_state()
      assert completed.completed_at
      assert completed.discarded_at == nil

      assert {:error, :invalid_transition} = Training.discard_workout(scope, stale_workout)

      reloaded = Training.get_workout!(scope, workout.id)
      assert reloaded.lifecycle_state == Workout.completed_state()
      assert reloaded.completed_at
      assert reloaded.discarded_at == nil
    end

    test "create_workout_from_plan/2 propagates open workout changeset errors", %{scope: scope} do
      plan = workout_plan_fixture(scope)
      draft_workout_fixture(scope, DateTime.utc_now() |> DateTime.truncate(:second))

      assert {:error, %Ecto.Changeset{} = changeset} =
               Training.create_workout_from_plan(scope, plan.id)

      assert "cannot start another workout while one is already open" in errors_on(changeset).started_at
    end

    test "create_workout_set/3 supports advanced set types", %{scope: scope} do
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      exercise = exercise_fixture(scope)

      assert {:ok, set} =
               Training.create_workout_set(scope, workout, %{
                 exercise_id: exercise.id,
                 weight: "100",
                 reps: "12",
                 kind: "myo_reps"
               })

      assert set.kind == "myo_reps"
      assert "superset" in Fittrack.Training.WorkoutSet.kinds()
      assert "amrap" in Fittrack.Training.WorkoutSet.kinds()
    end

    test "completed workout queries use lifecycle state", %{scope: scope} do
      today = Date.utc_today()
      started_at = DateTime.new!(today, ~T[12:00:00], "Etc/UTC")

      {:ok, completed_workout} =
        Training.create_workout(scope, %{
          started_at: started_at
        })

      {:ok, _set} =
        Training.create_workout_set(scope, completed_workout, %{
          exercise_id: exercise_fixture(scope).id,
          weight: "100",
          reps: "5",
          kind: "normal"
        })

      assert {:ok, completed_workout} = Training.complete_workout(scope, completed_workout)

      {:ok, _active_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.add(started_at, 3600, :second)
        })

      assert [%{date: ^today, count: 1}] =
               Training.completed_workout_dates_with_counts(scope, today, today)

      assert [workout] = Training.list_completed_workouts_in_date_range(scope, today, today)
      assert workout.id == completed_workout.id
    end

    test "workout counts and calendar dates use completed lifecycle state", %{
      scope: scope
    } do
      today = Date.utc_today()
      started_at = DateTime.new!(today, ~T[12:00:00], "Etc/UTC")

      {:ok, completed_workout} = Training.create_workout(scope, %{started_at: started_at})

      {:ok, _set} =
        Training.create_workout_set(scope, completed_workout, %{
          exercise_id: exercise_fixture(scope).id,
          weight: "100",
          reps: "5",
          kind: "normal"
        })

      assert {:ok, _completed_workout} = Training.complete_workout(scope, completed_workout)

      {:ok, _active_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.add(started_at, 3600, :second)
        })

      assert Training.count_workouts(scope) == 1
      assert Training.count_weekly_workouts(scope) == 1

      assert Training.workout_dates_in_month(
               scope,
               Date.beginning_of_month(today),
               Date.end_of_month(today)
             ) == [today]

      assert [%{date: ^today, count: 1}] =
               Training.workout_dates_in_month_with_counts(
                 scope,
                 Date.beginning_of_month(today),
                 Date.end_of_month(today)
               )
    end

    test "log_exercise_set/2 rejects unauthorized exercise", %{scope: scope} do
      assert {:error, :unauthorized} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => 999_999,
                 "weight" => "100",
                 "reps" => "5"
               })
    end

    test "generate_ai_workout_plan/2 generates and saves workout plan", %{scope: scope} do
      exercise_fixture(scope)

      params = %{
        "primary_goal" => "hypertrophy",
        "secondary_goal" => "strength",
        "training_styles" => ["hypertrophy", "mobility"],
        "training_split" => ["full_body", "hybrid"],
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "3",
        "duration_minutes" => "30"
      }

      assert {:ok, plan} = Training.generate_ai_workout_plan(scope, params)
      assert plan.name =~ "AI Workout Plan"
      assert plan.goal == "hypertrophy"
      assert plan.primary_goal == "hypertrophy"
      assert plan.secondary_goal == "strength"
      assert plan.training_styles == ["hypertrophy", "mobility"]
      assert plan.training_split == ["full_body", "hybrid"]
      assert plan.difficulty == "beginner"
      assert plan.estimated_duration_minutes == 30
      assert length(plan.workout_plan_exercises) > 0

      assert Enum.all?(
               plan.workout_plan_exercises,
               &(&1.target_kind in Fittrack.Training.WorkoutSet.kinds())
             )
    end

    test "generate_ai_workout_plan/2 selects WGER-backed templates before personal exercises", %{
      scope: scope
    } do
      exercise_fixture(scope, %{name: "Personal Push-up", equipment: "bodyweight"})

      {:ok, _template} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          source_id: 90_001,
          name: "WGER Bench Press",
          primary_muscle: "Chest",
          equipment: "Bodyweight",
          difficulty: "beginner",
          notes: "Template imported from WGER"
        })
        |> Fittrack.Repo.insert()

      params = %{
        "primary_goal" => "strength",
        "experience" => "beginner",
        "equipment" => ["bodyweight"],
        "days_per_week" => "2",
        "duration_minutes" => "30"
      }

      assert {:ok, plan} = Training.generate_ai_workout_plan(scope, params)

      assert Enum.any?(plan.workout_plan_exercises, fn plan_exercise ->
               plan_exercise.exercise.source_template_id
             end)
    end

    test "generate_ai_workout_plan/2 includes curated substitution templates in exercise pool", %{
      scope: scope
    } do
      {:ok, bench} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          source_id: 90_101,
          name: "Template Barbell Bench Press",
          primary_muscle: "Chest",
          equipment: "Barbell",
          difficulty: "beginner"
        })
        |> Fittrack.Repo.insert()

      {:ok, dumbbell_press} =
        %ExerciseTemplate{}
        |> ExerciseTemplate.changeset(%{
          source_id: 90_102,
          name: "Template Dumbbell Bench Press",
          primary_muscle: "Chest",
          equipment: "Dumbbell",
          difficulty: "beginner"
        })
        |> Fittrack.Repo.insert()

      assert {:ok, _substitution} =
               Training.create_exercise_substitution(bench, dumbbell_press, %{
                 reason: "equipment",
                 similarity_score: 94,
                 reason_quality: 88,
                 equipment_requirements: ["Dumbbell"],
                 difficulty_delta: 0
               })

      params = %{
        "primary_goal" => "strength",
        "experience" => "beginner",
        "equipment" => ["barbell"],
        "days_per_week" => "2",
        "duration_minutes" => "30"
      }

      assert {:ok, _plan} = Training.generate_ai_workout_plan(scope, params)

      names = scope |> Training.list_exercises() |> Enum.map(& &1.name)
      assert "Template Barbell Bench Press" in names
      assert "Template Dumbbell Bench Press" in names
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

  defp draft_workout_fixture(scope, started_at) do
    %Workout{}
    |> Workout.lifecycle_changeset(%{
      started_at: started_at,
      lifecycle_state: Workout.draft_state()
    })
    |> Ecto.Changeset.put_change(:user_id, scope.user.id)
    |> Repo.insert!()
  end
end
