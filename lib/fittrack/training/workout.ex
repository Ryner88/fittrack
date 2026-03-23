defmodule Fittrack.Training.Workout do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutSet

  schema "workout_sessions" do
    field :started_at, :utc_datetime
    field :notes, :string

    belongs_to :user, User
    has_many :workout_sets, WorkoutSet, foreign_key: :workout_session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout, attrs) do
    workout
    |> cast(attrs, [:started_at, :notes, :user_id])
    |> validate_required([:started_at])
  end
end
