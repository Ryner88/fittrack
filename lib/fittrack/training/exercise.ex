defmodule Fittrack.Training.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutSet

  schema "exercises" do
    field :name, :string
    field :primary_muscle, :string
    field :equipment, :string
    field :notes, :string

    belongs_to :user, User
    has_many :workout_sets, WorkoutSet

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [:name, :primary_muscle, :equipment, :notes])
    |> validate_required([:name, :primary_muscle, :equipment])
  end
end
