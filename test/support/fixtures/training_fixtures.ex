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
end
