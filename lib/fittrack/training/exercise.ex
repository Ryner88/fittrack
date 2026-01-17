defmodule Fittrack.Training.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exercises" do
    field :name, :string
    field :primary_muscle, :string
    field :equipment, :string
    field :notes, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [:name, :primary_muscle, :equipment, :notes])
    |> validate_required([:name, :primary_muscle, :equipment, :notes])
  end
end
