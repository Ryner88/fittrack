defmodule Fittrack.Training.WorkoutSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutSet

  schema "workout_sessions" do
    field :started_at, :utc_datetime
    field :notes, :string

    belongs_to :user, User
    has_many :workout_sets, WorkoutSet

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_session, attrs) do
    workout_session
    |> cast(attrs, [:started_at, :notes])
    |> validate_required([:started_at])
  end
end
