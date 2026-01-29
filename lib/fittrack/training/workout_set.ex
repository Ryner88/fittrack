defmodule Fittrack.Training.WorkoutSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Exercise
  alias Fittrack.Training.WorkoutSession

  schema "workout_sets" do
    field :weight, :decimal
    field :reps, :integer
    field :rpe, :decimal
    field :rest_seconds, :integer
    field :notes, :string
    field :kind, :string, default: "normal"

    belongs_to :workout_session, WorkoutSession
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @kinds [
    "normal",
    "warm_up",
    "right",
    "left",
    "failure",
    "drop_set",
    "negative_reps",
    "partial_reps",
    "myo_reps",
    "feeder_set",
    "top_set",
    "back_off_set"
  ]

  @kind_options [
    {"N Normal", "normal"},
    {"W Warm Up", "warm_up"},
    {"R Right", "right"},
    {"L Left", "left"},
    {"F Failure", "failure"},
    {"D Drop Set", "drop_set"},
    {"N Negative Reps", "negative_reps"},
    {"P Partial Reps", "partial_reps"},
    {"M Myo Reps", "myo_reps"},
    {"F Feeder Set", "feeder_set"},
    {"T Top Set", "top_set"},
    {"B Back Off Set", "back_off_set"}
  ]

  @kind_labels %{
    "normal" => "Normal",
    "warm_up" => "Warm Up",
    "right" => "Right",
    "left" => "Left",
    "failure" => "Failure",
    "drop_set" => "Drop Set",
    "negative_reps" => "Negative Reps",
    "partial_reps" => "Partial Reps",
    "myo_reps" => "Myo Reps",
    "feeder_set" => "Feeder Set",
    "top_set" => "Top Set",
    "back_off_set" => "Back Off Set"
  }

  @doc false
  def changeset(workout_set, attrs) do
    workout_set
    |> cast(attrs, [:weight, :reps, :rpe, :rest_seconds, :notes, :kind, :exercise_id])
    |> validate_required([:weight, :reps, :kind, :exercise_id])
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> validate_number(:reps, greater_than: 0)
    |> validate_number(:rpe, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:rest_seconds, greater_than_or_equal_to: 0)
    |> validate_inclusion(:kind, @kinds)
  end

  def kinds do
    @kinds
  end

  def kind_options do
    @kind_options
  end

  def kind_label(kind) do
    Map.get(@kind_labels, kind, "Normal")
  end
end
