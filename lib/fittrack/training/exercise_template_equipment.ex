defmodule Fittrack.Training.ExerciseTemplateEquipment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.ExerciseEquipment
  alias Fittrack.Training.ExerciseTemplate

  schema "exercise_template_equipment" do
    field :position, :integer, default: 0

    belongs_to :exercise_template, ExerciseTemplate
    belongs_to :exercise_equipment, ExerciseEquipment

    timestamps(type: :utc_datetime)
  end

  def changeset(template_equipment, attrs) do
    template_equipment
    |> cast(attrs, [:exercise_template_id, :exercise_equipment_id, :position])
    |> validate_required([:exercise_template_id, :exercise_equipment_id])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint([:exercise_template_id, :exercise_equipment_id])
  end
end
