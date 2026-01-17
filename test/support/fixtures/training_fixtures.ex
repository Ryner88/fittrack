defmodule Fittrack.TrainingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fittrack.Training` context.
  """

  @doc """
  Generate a exercise.
  """
  def exercise_fixture(attrs \\ %{}) do
    {:ok, exercise} =
      attrs
      |> Enum.into(%{
        equipment: "some equipment",
        name: "some name",
        notes: "some notes",
        primary_muscle: "some primary_muscle"
      })
      |> Fittrack.Training.create_exercise()

    exercise
  end
end
