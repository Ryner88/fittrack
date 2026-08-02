defmodule Fittrack.Training.Workout do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutSet

  @draft_state "draft"
  @active_state "active"
  @completed_state "completed"
  @discarded_state "discarded"
  @lifecycle_states [@draft_state, @active_state, @completed_state, @discarded_state]
  @open_lifecycle_states [@draft_state, @active_state]

  schema "workout_sessions" do
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :discarded_at, :utc_datetime
    field :lifecycle_state, :string, default: @active_state
    field :notes, :string

    belongs_to :user, User
    has_many :workout_sets, WorkoutSet, foreign_key: :workout_session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout, attrs) do
    workout
    |> cast(attrs, [:started_at, :notes])
    |> validate_required([:started_at])
  end

  def lifecycle_changeset(workout, attrs) do
    workout
    |> cast(attrs, [:lifecycle_state, :started_at, :completed_at, :discarded_at, :notes])
    |> validate_required([:lifecycle_state, :started_at])
    |> validate_inclusion(:lifecycle_state, @lifecycle_states)
    |> check_constraint(:lifecycle_state, name: :workout_sessions_lifecycle_state_check)
    |> unique_constraint(:started_at,
      name: :workout_sessions_one_open_per_user_idx,
      message: "cannot start another workout while one is already open"
    )
  end

  def lifecycle_states, do: @lifecycle_states

  def open_lifecycle_states, do: @open_lifecycle_states

  def draft_state, do: @draft_state

  def active_state, do: @active_state

  def completed_state, do: @completed_state

  def discarded_state, do: @discarded_state
end
