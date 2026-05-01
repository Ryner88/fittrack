defmodule Fittrack.TrainingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fittrack.Training` context.
  """

  @doc """
  Generate a exercise.
  """
  def exercise_fixture(scope \\ nil) do
    scope = scope || Fittrack.AccountsFixtures.user_scope_fixture()

    attrs = %{
      equipment: "some equipment",
      name: "some name",
      notes: "some notes",
      primary_muscle: "some primary_muscle"
    }

    {:ok, exercise} = Fittrack.Training.create_exercise(scope, attrs)

    exercise
  end

  @doc """
  Generate a workout plan.
  """
  def workout_plan_fixture(scope \\ nil, attrs \\ %{}) do
    scope = scope || Fittrack.AccountsFixtures.user_scope_fixture()
    exercise = exercise_fixture(scope)

    attrs =
      Map.merge(
        %{
          "name" => "Push strength template",
          "goal" => "strength",
          "primary_style" => "strength",
          "workout_plan_exercises" => [
            %{
              "position" => 1,
              "exercise_id" => exercise.id,
              "target_sets" => 3,
              "target_reps_min" => 4,
              "target_reps_max" => 6,
              "rest_seconds" => 120,
              "scheduled_day" => "Monday"
            },
            %{
              "position" => 2,
              "exercise_id" => exercise.id,
              "target_sets" => 3,
              "target_reps_min" => 4,
              "target_reps_max" => 6,
              "rest_seconds" => 120,
              "scheduled_day" => "Thursday"
            }
          ]
        },
        attrs
      )

    {:ok, workout_plan} = Fittrack.Training.create_workout_plan(scope, attrs)

    workout_plan
  end
end
