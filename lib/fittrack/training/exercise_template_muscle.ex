defmodule Fittrack.Training.ExerciseTemplateMuscle do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseMuscle
  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_template_muscles" do
    field :role, :string
    field :position, :integer, default: 0

    belongs_to :exercise_template, ExerciseTemplate
    belongs_to :exercise_muscle, ExerciseMuscle

    timestamps(type: :utc_datetime)
  end

  def changeset(template_muscle, attrs) do
    template_muscle
    |> cast(attrs, [:exercise_template_id, :exercise_muscle_id, :role, :position])
    |> validate_required([:exercise_template_id, :exercise_muscle_id, :role])
    |> validate_inclusion(:role, ["primary", "secondary"])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:exercise_template_id, :exercise_muscle_id, :role])
  end
end
