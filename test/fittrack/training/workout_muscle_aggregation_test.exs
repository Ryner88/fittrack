defmodule Fittrack.Training.WorkoutMuscleAggregationTest do
  use Fittrack.DataCase

  alias Fittrack.Repo
  alias Fittrack.Training
  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate
  alias Fittrack.Training.ExerciseTemplateMuscle
  alias Fittrack.Training.Workout
  alias Fittrack.Training.WorkoutMuscleSummary

  import Fittrack.AccountsFixtures
  import Fittrack.TrainingFixtures

  setup do
    %{scope: user_scope_fixture()}
  end

  test "complete_workout/2 persists normalized live muscle summaries", %{scope: scope} do
    template = exercise_template_fixture(%{name: "Template Bench", primary_muscle: "Chest"})
    chest = exercise_muscle_fixture("Chest", "upper")
    triceps = exercise_muscle_fixture("Triceps", "arms")
    link_template_muscle(template, chest, "primary", 0)
    link_template_muscle(template, triceps, "secondary", 1)

    exercise =
      exercise_fixture(scope, %{
        name: "Bench Press",
        primary_muscle: "Legacy Chest",
        secondary_muscles: ["Legacy Arms"],
        equipment: "Barbell",
        source_template_id: template.id
      })

    {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
    {:ok, _set} = create_set(scope, workout, exercise, "100", 5)
    {:ok, _set} = create_set(scope, workout, exercise, "120", 3)

    assert {:ok, completed} = Training.complete_workout(scope, workout)

    summaries = summaries_by_role(scope, completed)
    assert summary_stats(summaries, "primary", "chest") == {"Chest", 2, 8, "860"}
    assert summary_stats(summaries, "secondary", "triceps") == {"Triceps", 2, 8, "860"}
  end

  test "complete_workout/2 falls back to exercise muscle strings", %{scope: scope} do
    exercise =
      exercise_fixture(scope, %{
        name: "Goblet Squat",
        primary_muscle: "Quads",
        secondary_muscles: ["Glutes", "Calves"],
        equipment: "Kettlebell"
      })

    {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
    {:ok, _set} = create_set(scope, workout, exercise, "40", 10)

    assert {:ok, completed} = Training.complete_workout(scope, workout)

    summaries = summaries_by_role(scope, completed)
    assert summary_stats(summaries, "primary", "quads") == {"Quads", 1, 10, "400"}
    assert summary_stats(summaries, "secondary", "glutes") == {"Glutes", 1, 10, "400"}
    assert summary_stats(summaries, "secondary", "calves") == {"Calves", 1, 10, "400"}
  end

  test "origin snapshot muscles take precedence over changed live source muscles", %{scope: scope} do
    template =
      exercise_template_fixture(%{name: "Snapshot Bench", primary_muscle: "Template Chest"})

    chest = exercise_muscle_fixture("Snapshot Chest", "upper")
    triceps = exercise_muscle_fixture("Snapshot Triceps", "arms")
    link_template_muscle(template, chest, "primary", 0)
    link_template_muscle(template, triceps, "secondary", 1)

    exercise =
      exercise_fixture(scope, %{
        name: "Snapshot Bench",
        primary_muscle: "Exercise Chest",
        secondary_muscles: ["Exercise Triceps"],
        equipment: "Barbell",
        source_template_id: template.id
      })

    plan = workout_plan_fixture(scope, %{"workout_plan_exercises" => [plan_entry(exercise)]})
    {:ok, workout} = Training.create_workout_from_plan(scope, plan.id)

    chest
    |> ExerciseMuscle.changeset(%{name: "Changed Chest", region: "upper"})
    |> Repo.update!()

    {:ok, _set} = create_set(scope, workout, exercise, "100", 5)
    assert {:ok, completed} = Training.complete_workout(scope, workout)

    summaries = summaries_by_role(scope, completed)

    assert summary_stats(summaries, "primary", "snapshot chest") ==
             {"Snapshot Chest", 1, 5, "500"}

    refute Map.has_key?(summaries, {"primary", "changed chest"})
  end

  test "origin summaries remain stable when source template is deleted before completion", %{
    scope: scope
  } do
    template = exercise_template_fixture(%{name: "Delete Stable Row", primary_muscle: "Back"})
    back = exercise_muscle_fixture("Latissimus", "back")
    link_template_muscle(template, back, "primary", 0)

    exercise =
      exercise_fixture(scope, %{
        name: "Stable Row",
        primary_muscle: "Rows",
        equipment: "Cable",
        source_template_id: template.id
      })

    plan = workout_plan_fixture(scope, %{"workout_plan_exercises" => [plan_entry(exercise)]})
    {:ok, workout} = Training.create_workout_from_plan(scope, plan.id)
    Repo.delete!(template)

    {:ok, _set} = create_set(scope, workout, exercise, "80", 8)
    assert {:ok, completed} = Training.complete_workout(scope, workout)

    summaries = summaries_by_role(scope, completed)
    assert summary_stats(summaries, "primary", "latissimus") == {"Latissimus", 1, 8, "640"}
  end

  test "complete_workout/2 rebuilds summaries idempotently", %{scope: scope} do
    template = exercise_template_fixture(%{name: "Hamstring Curl", primary_muscle: "Hamstrings"})
    hamstrings = exercise_muscle_fixture("Hamstrings", "legs")
    link_template_muscle(template, hamstrings, "primary", 0)

    exercise =
      exercise_fixture(scope, %{
        name: "Hamstring Curl",
        primary_muscle: "Changed Later",
        equipment: "Machine",
        source_template_id: template.id
      })

    {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
    {:ok, _set} = create_set(scope, workout, exercise, "135", 5)

    assert {:ok, completed} = Training.complete_workout(scope, workout)
    Repo.delete!(template)
    assert {:ok, completed_again} = Training.complete_workout(scope, completed)

    summaries = Training.list_workout_muscle_summaries(scope, completed_again)
    assert length(summaries) == 1

    assert summary_stats(summaries_by_role(scope, completed_again), "primary", "hamstrings") ==
             {"Hamstrings", 1, 5, "675"}
  end

  test "log_exercise_set/2 quick logs completed workout muscle summaries", %{scope: scope} do
    exercise = exercise_fixture(scope, %{primary_muscle: "Shoulders", equipment: "Dumbbell"})

    assert {:ok, set} =
             Training.log_exercise_set(scope, %{
               "exercise_id" => exercise.id,
               "weight" => "35",
               "reps" => "12"
             })

    workout = Training.get_workout!(scope, set.workout_session_id)
    assert workout.lifecycle_state == Workout.completed_state()

    assert summary_stats(summaries_by_role(scope, workout), "primary", "shoulders") ==
             {"Shoulders", 1, 12, "420"}
  end

  test "empty completed workouts persist no muscle summaries", %{scope: scope} do
    {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
    assert {:ok, completed} = Training.complete_workout(scope, workout)

    assert Training.list_workout_muscle_summaries(scope, completed) == []
  end

  test "muscle summaries are scoped and cascade with workout deletion", %{scope: scope} do
    other_scope = user_scope_fixture()
    exercise = exercise_fixture(scope, %{primary_muscle: "Biceps", equipment: "Dumbbell"})
    {:ok, workout} = Training.create_workout(scope, %{started_at: DateTime.utc_now()})
    {:ok, _set} = create_set(scope, workout, exercise, "25", 10)
    assert {:ok, completed} = Training.complete_workout(scope, workout)

    assert [_summary] = Training.list_workout_muscle_summaries(scope, completed)
    assert Training.list_workout_muscle_summaries(other_scope, completed) == []

    Repo.delete!(completed)
    assert Repo.aggregate(WorkoutMuscleSummary, :count, :id) == 0
  end

  defp create_set(scope, workout, exercise, weight, reps) do
    Training.create_workout_set(scope, workout, %{
      "exercise_id" => exercise.id,
      "weight" => weight,
      "reps" => reps
    })
  end

  defp summaries_by_role(scope, workout) do
    scope
    |> Training.list_workout_muscle_summaries(workout)
    |> Map.new(&{{&1.role, &1.muscle_token}, &1})
  end

  defp summary_stats(summaries, role, token) do
    summary = Map.fetch!(summaries, {role, token})
    volume = summary.volume |> Decimal.normalize() |> Decimal.to_string(:normal)
    {summary.muscle_name, summary.sets, summary.reps, volume}
  end

  defp exercise_template_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          name: "Template Exercise",
          primary_muscle: "Chest",
          secondary_muscles: [],
          equipment: "Barbell"
        },
        attrs
      )

    {:ok, template} =
      %ExerciseTemplate{}
      |> ExerciseTemplate.changeset(attrs)
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

  defp plan_entry(exercise) do
    %{
      "position" => 1,
      "exercise_id" => exercise.id,
      "target_sets" => 3,
      "target_reps_min" => 5,
      "target_reps_max" => 8,
      "rest_seconds" => 120,
      "scheduled_day" => "Monday"
    }
  end
end
