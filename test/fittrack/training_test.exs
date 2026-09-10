defmodule Fittrack.TrainingTest do
  use Fittrack.DataCase

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.Workout
  alias Fittrack.Training.WorkoutOriginSnapshot

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

    test "create_workout/2 accepts atom-keyed attrs", %{scope: scope} do
      assert {:ok, %Workout{} = workout} =
               Training.create_workout(scope, %{
                 started_at: DateTime.utc_now(),
                 notes: "Atom keyed start"
               })

      assert workout.lifecycle_state == Workout.active_state()
      assert workout.notes == "Atom keyed start"
    end

    test "log_exercise_set/2 creates a completed workout when no workout is open", %{
      scope: scope
    } do
      exercise = exercise_fixture(scope)

      assert {:ok, set} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => exercise.id,
                 "weight" => "100",
                 "reps" => "5"
               })

      workout = Training.get_workout!(scope, set.workout_session_id)

      assert workout.lifecycle_state == Workout.completed_state()
      assert workout.completed_at
      assert Training.get_open_workout(scope) == nil
      assert Decimal.equal?(set.weight, Decimal.new("100"))
    end

    test "log_exercise_set/2 rolls back the workout shell when the quick set is invalid", %{
      scope: scope
    } do
      exercise = exercise_fixture(scope)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => exercise.id,
                 "weight" => "100",
                 "reps" => "0"
               })

      assert "must be greater than 0" in errors_on(changeset).reps
      assert Training.get_open_workout(scope) == nil

      assert Repo.aggregate(
               from(workout in Workout, where: workout.user_id == ^scope.user.id),
               :count
             ) ==
               0
    end

    test "log_exercise_set/2 adds to an active workout and leaves it active", %{scope: scope} do
      exercise = exercise_fixture(scope)
      {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})

      assert {:ok, set} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => exercise.id,
                 "weight" => "100",
                 "reps" => "5"
               })

      assert set.workout_session_id == workout.id

      reloaded = Training.get_workout!(scope, workout.id)
      assert reloaded.lifecycle_state == Workout.active_state()
      assert reloaded.completed_at == nil
    end

    test "log_exercise_set/2 adds to a draft, activates it, and replaces the shell timestamp", %{
      scope: scope
    } do
      old_started_at =
        DateTime.utc_now()
        |> DateTime.add(-7 * 24 * 60 * 60, :second)
        |> DateTime.truncate(:second)

      draft = draft_workout_fixture(scope, old_started_at)
      exercise = exercise_fixture(scope)

      assert {:ok, set} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => exercise.id,
                 "weight" => "100",
                 "reps" => "5"
               })

      assert set.workout_session_id == draft.id

      reloaded = Training.get_workout!(scope, draft.id)
      assert reloaded.lifecycle_state == Workout.active_state()
      assert DateTime.compare(reloaded.started_at, old_started_at) == :gt
      assert reloaded.completed_at == nil
    end

    test "log_exercise_set/2 leaves a draft unchanged when the quick set is invalid", %{
      scope: scope
    } do
      old_started_at = DateTime.utc_now() |> DateTime.truncate(:second)
      draft = draft_workout_fixture(scope, old_started_at)
      exercise = exercise_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Training.log_exercise_set(scope, %{
                 "exercise_id" => exercise.id,
                 "weight" => "100",
                 "reps" => "0"
               })

      reloaded = Training.get_workout!(scope, draft.id)
      assert reloaded.lifecycle_state == Workout.draft_state()
      assert reloaded.started_at == old_started_at
      assert reloaded.workout_sets == []
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

    test "create_workout_from_plan/2 captures immutable ordered plan origin snapshots", %{
      scope: scope
    } do
      template = exercise_template_fixture()
      chest = exercise_muscle_fixture("Chest", "upper")
      triceps = exercise_muscle_fixture("Triceps", "arms")
      link_template_muscle(template, chest, "primary", 0)
      link_template_muscle(template, triceps, "secondary", 1)

      exercise =
        exercise_fixture(scope, %{
          name: "User Bench Press",
          slug: "user-bench-press",
          primary_muscle: "Chest",
          secondary_muscles: ["Triceps"],
          equipment: "Barbell",
          movement_pattern: "push",
          exercise_category: "compound",
          training_style_tags: ["strength"],
          source_template_id: template.id
        })

      {:ok, plan} =
        Training.create_workout_plan(scope, %{
          "name" => "Snapshot Strength Plan",
          "description" => "Original description",
          "goal" => "strength",
          "primary_style" => "powerlifting",
          "secondary_style_tags" => ["strength"],
          "primary_goal" => "strength",
          "training_styles" => ["strength"],
          "training_split" => ["upper_lower"],
          "difficulty" => "intermediate",
          "estimated_duration_minutes" => 50,
          "workout_plan_exercises" => [
            %{
              "position" => 2,
              "exercise_id" => exercise.id,
              "target_sets" => 4,
              "target_reps_min" => 3,
              "target_reps_max" => 5,
              "rest_seconds" => 180,
              "target_kind" => "top_set",
              "scheduled_day" => "Thursday",
              "notes" => "Heavy"
            },
            %{
              "position" => 1,
              "exercise_id" => exercise.id,
              "target_sets" => 3,
              "target_reps_min" => 6,
              "target_reps_max" => 8,
              "rest_seconds" => 120,
              "target_kind" => "normal",
              "scheduled_day" => "Monday",
              "notes" => "Volume"
            }
          ]
        })

      assert {:ok, workout} = Training.create_workout_from_plan(scope, plan.id)
      snapshot = Training.get_workout_origin_snapshot(scope, workout)

      assert %WorkoutOriginSnapshot{} = snapshot
      assert snapshot.workout_session_id == workout.id
      assert snapshot.source_workout_plan_id == plan.id
      assert snapshot.schema_version == 1
      assert snapshot.plan_name == "Snapshot Strength Plan"
      assert snapshot.plan_primary_style == "powerlifting"
      assert snapshot.plan_training_split == ["upper_lower"]

      assert [first, second] = snapshot.exercise_snapshots
      assert Enum.map(snapshot.exercise_snapshots, & &1.position) == [1, 2]
      assert first.target_reps_min == 6
      assert first.target_reps_max == 8
      assert first.exercise_name == "User Bench Press"
      assert first.exercise_secondary_muscles == ["Triceps"]
      assert first.template_name == "Template Bench Press"
      assert first.template_canonical_slug == "template-bench-press"

      assert Enum.map(first.muscle_snapshots, & &1.muscle_name) == ["Chest", "Triceps"]
      assert Enum.map(first.muscle_snapshots, & &1.role) == ["primary", "secondary"]

      assert second.target_kind == "top_set"
      assert second.notes == "Heavy"
    end

    test "create_workout_from_plan/2 snapshots user exercises without source templates", %{
      scope: scope
    } do
      exercise =
        exercise_fixture(scope, %{
          name: "Custom Sled Push",
          primary_muscle: "Quads",
          secondary_muscles: ["Glutes", "Calves"],
          equipment: "Sled"
        })

      plan = workout_plan_fixture(scope, %{"workout_plan_exercises" => plan_entries(exercise)})

      assert {:ok, workout} = Training.create_workout_from_plan(scope, plan.id)
      snapshot = Training.get_workout_origin_snapshot(scope, workout)
      assert [exercise_snapshot | _] = snapshot.exercise_snapshots

      assert exercise_snapshot.source_template_id == nil
      assert exercise_snapshot.exercise_name == "Custom Sled Push"
      assert exercise_snapshot.exercise_primary_muscle == "Quads"
      assert exercise_snapshot.exercise_secondary_muscles == ["Glutes", "Calves"]
      assert exercise_snapshot.template_name == nil
      assert exercise_snapshot.muscle_snapshots == []
    end

    test "create_workout_from_plan/2 keeps manual workouts snapshot-free", %{scope: scope} do
      assert {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
      assert Training.get_workout_origin_snapshot(scope, workout) == nil

      assert {:ok, completed} = Training.complete_workout(scope, workout)
      assert Training.get_workout_origin_snapshot(scope, completed) == nil
    end

    test "create_workout_from_plan/2 hides other users plans and creates no snapshot" do
      owner_scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      plan = workout_plan_fixture(owner_scope)

      assert {:error, :not_found} = Training.create_workout_from_plan(other_scope, plan.id)
      assert Training.get_open_workout(other_scope) == nil
      assert Repo.aggregate(WorkoutOriginSnapshot, :count, :id) == 0
    end

    test "create_workout_from_plan/2 rolls back workout when snapshot capture fails", %{
      scope: scope
    } do
      exercise = exercise_fixture(scope, %{name: "Rollback Press", equipment: "Cable"})
      plan = workout_plan_fixture(scope, %{"workout_plan_exercises" => plan_entries(exercise)})

      Repo.update_all(
        from(exercise in Fittrack.Training.Exercise, where: exercise.id == ^exercise.id),
        set: [name: nil]
      )

      assert {:error, %Ecto.Changeset{} = changeset} =
               Training.create_workout_from_plan(scope, plan.id)

      assert "can't be blank" in errors_on(changeset).exercise_name
      assert Training.get_open_workout(scope) == nil
      assert Repo.aggregate(WorkoutOriginSnapshot, :count, :id) == 0
    end

    test "origin snapshots do not change after source records are edited or deleted", %{
      scope: scope
    } do
      template = exercise_template_fixture()

      exercise =
        exercise_fixture(scope, %{
          name: "Original Snapshot Exercise",
          primary_muscle: "Chest",
          equipment: "Barbell",
          source_template_id: template.id
        })

      plan = workout_plan_fixture(scope, %{"workout_plan_exercises" => plan_entries(exercise)})

      assert {:ok, workout} = Training.create_workout_from_plan(scope, plan.id)
      snapshot = Training.get_workout_origin_snapshot(scope, workout)
      assert [exercise_snapshot] = snapshot.exercise_snapshots
      assert snapshot.plan_name == plan.name
      assert exercise_snapshot.exercise_name == "Original Snapshot Exercise"
      assert exercise_snapshot.template_name == "Template Bench Press"

      assert {:ok, _plan} = Training.update_workout_plan(scope, plan, %{name: "Changed Plan"})

      assert {:ok, _exercise} =
               Training.update_exercise(scope, exercise, %{name: "Changed Exercise"})

      {:ok, _template} =
        template
        |> ExerciseTemplate.changeset(%{name: "Changed Template"})
        |> Repo.update()

      assert {:ok, _deleted_plan} = Training.delete_workout_plan(scope, plan)

      reloaded_snapshot = Training.get_workout_origin_snapshot(scope, workout)
      assert [reloaded_exercise_snapshot] = reloaded_snapshot.exercise_snapshots

      assert reloaded_snapshot.plan_name == snapshot.plan_name
      assert reloaded_exercise_snapshot.exercise_name == exercise_snapshot.exercise_name
      assert reloaded_exercise_snapshot.template_name == exercise_snapshot.template_name
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

    test "completed workout history filters exclude non-completed lifecycle states", %{
      scope: scope
    } do
      today = Date.utc_today()
      started_at = DateTime.new!(today, ~T[12:00:00], "Etc/UTC")

      {:ok, completed_workout} = Training.create_workout(scope, %{started_at: started_at})
      assert {:ok, completed_workout} = Training.complete_workout(scope, completed_workout)

      draft =
        draft_workout_fixture(scope, DateTime.add(started_at, 3600, :second))

      assert [workout] = Training.list_completed_workouts_in_date_range(scope, today, today)
      assert workout.id == completed_workout.id
      refute workout.id == draft.id

      Repo.delete!(draft)

      {:ok, active_workout} =
        Training.create_workout(scope, %{started_at: DateTime.add(started_at, 7200, :second)})

      assert [workout] = Training.list_completed_workouts_in_date_range(scope, today, today)
      assert workout.id == completed_workout.id
      refute workout.id == active_workout.id

      assert {:ok, discarded_workout} = Training.discard_workout(scope, active_workout)

      assert [workout] = Training.list_completed_workouts_in_date_range(scope, today, today)
      assert workout.id == completed_workout.id
      refute workout.id == discarded_workout.id
    end

    test "history plan filters use captured plan identity after rename and delete", %{
      scope: scope
    } do
      today = Date.utc_today()
      exercise = exercise_fixture(scope, %{name: "History Plan Press", equipment: "Barbell"})

      {:ok, plan} =
        Training.create_workout_plan(scope, %{
          "name" => "Original History Plan",
          "goal" => "strength",
          "primary_style" => "strength",
          "workout_plan_exercises" => plan_entries(exercise)
        })

      {:ok, first_workout} = Training.create_workout_from_plan(scope, plan.id)
      {:ok, first_workout} = Training.complete_workout(scope, first_workout)

      assert {:ok, renamed_plan} =
               Training.update_workout_plan(scope, plan, %{name: "Renamed History Plan"})

      {:ok, second_workout} = Training.create_workout_from_plan(scope, renamed_plan.id)
      {:ok, second_workout} = Training.complete_workout(scope, second_workout)

      assert [
               %{id: plan_id, name: "Renamed History Plan"}
             ] = Training.list_history_plan_options(scope)

      assert plan_id == plan.id

      assert [newer, older] =
               Training.list_completed_workouts_in_date_range(scope, today, today,
                 plan_id: plan.id
               )

      assert newer.id == second_workout.id
      assert older.id == first_workout.id

      assert {:ok, _deleted_plan} = Training.delete_workout_plan(scope, renamed_plan)

      assert [
               %{id: ^plan_id, name: "Renamed History Plan"}
             ] = Training.list_history_plan_options(scope)

      assert [_, _] =
               Training.list_completed_workouts_in_date_range(scope, today, today,
                 plan_id: plan.id
               )
    end

    test "history muscle filters match primary and secondary summaries without duplicates", %{
      scope: scope
    } do
      today = Date.utc_today()
      started_at = DateTime.new!(today, ~T[12:00:00], "Etc/UTC")

      exercise =
        exercise_fixture(scope, %{
          name: "Chest Duplicate Summary",
          primary_muscle: "Chest",
          secondary_muscles: ["Chest"],
          equipment: "Dumbbell"
        })

      {:ok, workout} = Training.create_workout(scope, %{started_at: started_at})

      {:ok, _set} =
        Training.create_workout_set(scope, workout, %{
          exercise_id: exercise.id,
          weight: "100",
          reps: "5",
          kind: "normal"
        })

      assert {:ok, workout} = Training.complete_workout(scope, workout)

      other_scope = user_scope_fixture()
      other_exercise = exercise_fixture(other_scope, %{primary_muscle: "Chest"})
      {:ok, other_workout} = Training.create_workout(other_scope, %{started_at: started_at})

      {:ok, _set} =
        Training.create_workout_set(other_scope, other_workout, %{
          exercise_id: other_exercise.id,
          weight: "100",
          reps: "5",
          kind: "normal"
        })

      assert {:ok, _other_workout} = Training.complete_workout(other_scope, other_workout)

      assert [%{token: "chest", name: "Chest"}] = Training.list_history_muscle_options(scope)

      assert [filtered_workout] =
               Training.list_completed_workouts_in_date_range(scope, today, today,
                 muscle_token: "chest"
               )

      assert filtered_workout.id == workout.id
    end

    test "history filter options use deterministic case-insensitive ordering", %{
      scope: scope
    } do
      started_at = DateTime.utc_now() |> DateTime.truncate(:second)
      back = exercise_fixture(scope, %{name: "Ordering Row", primary_muscle: "Back"})
      chest = exercise_fixture(scope, %{name: "Ordering Press", primary_muscle: "Chest"})
      zulu_plan = history_plan(scope, "Zulu Plan", back)
      alpha_plan = history_plan(scope, "alpha Plan", chest)

      {:ok, zulu_workout} = Training.create_workout_from_plan(scope, zulu_plan.id)
      {:ok, _set} = history_set(scope, zulu_workout, back)
      {:ok, _zulu_workout} = Training.complete_workout(scope, zulu_workout)

      {:ok, alpha_workout} = Training.create_workout_from_plan(scope, alpha_plan.id)
      {:ok, _set} = history_set(scope, alpha_workout, chest)
      {:ok, _alpha_workout} = Training.complete_workout(scope, alpha_workout)

      {:ok, manual_workout} = Training.create_workout(scope, %{started_at: started_at})
      {:ok, _set} = history_set(scope, manual_workout, chest)
      {:ok, _manual_workout} = Training.complete_workout(scope, manual_workout)

      assert Enum.map(Training.list_history_plan_options(scope), & &1.name) == [
               "alpha Plan",
               "Zulu Plan"
             ]

      assert Enum.map(Training.list_history_muscle_options(scope), & &1.name) == [
               "Back",
               "Chest"
             ]
    end

    test "history filters combine date plan and muscle with all semantics for blanks", %{
      scope: scope
    } do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      chest = exercise_fixture(scope, %{primary_muscle: "Chest", equipment: "Dumbbell"})
      back = exercise_fixture(scope, %{name: "History Row", primary_muscle: "Back"})
      plan = history_plan(scope, "AND Chest Plan", chest)
      other_plan = history_plan(scope, "AND Back Plan", back)

      {:ok, matching} = Training.create_workout_from_plan(scope, plan.id)
      {:ok, _set} = history_set(scope, matching, chest)
      {:ok, matching} = Training.complete_workout(scope, matching)

      {:ok, wrong_muscle} = Training.create_workout_from_plan(scope, plan.id)
      {:ok, _set} = history_set(scope, wrong_muscle, back)
      {:ok, wrong_muscle} = Training.complete_workout(scope, wrong_muscle)

      {:ok, wrong_plan} = Training.create_workout_from_plan(scope, other_plan.id)
      {:ok, _set} = history_set(scope, wrong_plan, back)
      {:ok, wrong_plan} = Training.complete_workout(scope, wrong_plan)

      {:ok, wrong_date} =
        Training.create_workout(scope, %{
          started_at: DateTime.new!(yesterday, ~T[12:00:00], "Etc/UTC")
        })

      {:ok, _set} = history_set(scope, wrong_date, chest)
      {:ok, wrong_date} = Training.complete_workout(scope, wrong_date)

      assert [workout] =
               Training.list_completed_workouts_in_date_range(scope, today, today,
                 plan_id: plan.id,
                 muscle_token: "chest"
               )

      assert workout.id == matching.id

      today_ids =
        scope
        |> Training.list_completed_workouts_in_date_range(today, today,
          plan_id: "",
          muscle_token: ""
        )
        |> Enum.map(& &1.id)

      assert matching.id in today_ids
      assert wrong_muscle.id in today_ids
      assert wrong_plan.id in today_ids
      refute wrong_date.id in today_ids
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

    test "recent and popular exercise shortcuts exclude discarded workouts", %{scope: scope} do
      included = exercise_fixture(scope, %{name: "Included Press"})
      discarded_only = exercise_fixture(scope, %{name: "Discarded Pull"})

      {:ok, completed_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        })

      assert {:ok, _set} =
               Training.create_workout_set(scope, completed_workout, %{
                 exercise_id: included.id,
                 weight: "100",
                 reps: "5",
                 kind: "normal"
               })

      assert {:ok, _completed_workout} = Training.complete_workout(scope, completed_workout)

      {:ok, discarded_workout} =
        Training.create_workout(scope, %{
          started_at: DateTime.utc_now()
        })

      assert {:ok, _set} =
               Training.create_workout_set(scope, discarded_workout, %{
                 exercise_id: discarded_only.id,
                 weight: "100",
                 reps: "5",
                 kind: "normal"
               })

      assert {:ok, _set} =
               Training.create_workout_set(scope, discarded_workout, %{
                 exercise_id: discarded_only.id,
                 weight: "105",
                 reps: "5",
                 kind: "normal"
               })

      assert {:ok, _discarded_workout} = Training.discard_workout(scope, discarded_workout)

      assert [recent] = Training.list_recent_exercises(scope, limit: 5)
      assert recent.id == included.id

      assert [popular] = Training.list_popular_exercises(scope, limit: 5)
      assert popular.id == included.id
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

  defp exercise_template_fixture do
    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(%{
        name: "Template Bench Press",
        canonical_slug: "template-bench-press",
        primary_muscle: "Chest",
        secondary_muscles: ["Triceps"],
        equipment: "Barbell",
        movement_pattern: "push",
        exercise_category: "compound",
        training_style_tags: ["strength"]
      })
      |> Repo.insert()

    template
  end

  defp exercise_muscle_fixture(name, region) do
    {:ok, muscle} =
      %ExerciseMuscle{}
      |> ExerciseMuscle.changeset(%{name: name, region: region, source: "test"})
      |> Repo.insert()

    muscle
  end

  defp link_template_muscle(template, muscle, role, position) do
    {:ok, template_muscle} =
      %ExerciseTemplateMuscle{}
      |> ExerciseTemplateMuscle.changeset(%{
        exercise_template_id: template.id,
        exercise_muscle_id: muscle.id,
        role: role,
        position: position
      })
      |> Repo.insert()

    template_muscle
  end

  defp plan_entries(exercise) do
    [
      %{
        "position" => 1,
        "exercise_id" => exercise.id,
        "target_sets" => 3,
        "target_reps_min" => 8,
        "target_reps_max" => 10,
        "rest_seconds" => 90,
        "scheduled_day" => "Monday"
      }
    ]
  end

  defp history_plan(scope, name, exercise) do
    {:ok, plan} =
      Training.create_workout_plan(scope, %{
        "name" => name,
        "goal" => "strength",
        "primary_style" => "strength",
        "workout_plan_exercises" => plan_entries(exercise)
      })

    plan
  end

  defp history_set(scope, workout, exercise) do
    Training.create_workout_set(scope, workout, %{
      exercise_id: exercise.id,
      weight: "100",
      reps: "5",
      kind: "normal"
    })
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
