defmodule Fittrack.Training.ExerciseTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exercise_templates" do
    field :name, :string
    field :primary_muscle, :string
    field :equipment, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :primary_muscle, :equipment, :notes])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> update_change(:primary_muscle, &String.trim/1)
    |> update_change(:equipment, &String.trim/1)
    |> unique_constraint([:name, :equipment])
  end
end
