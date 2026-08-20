defmodule Fittrack.Training.WorkoutMuscleSummary do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Training.Workout

  schema "workout_muscle_summaries" do
    field :muscle_token, :string
    field :muscle_name, :string
    field :muscle_normalized_name, :string
    field :role, :string
    field :sets, :integer, default: 0
    field :reps, :integer, default: 0
    field :volume, :decimal, default: 0

    belongs_to :workout, Workout, foreign_key: :workout_session_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :muscle_token,
      :muscle_name,
      :muscle_normalized_name,
      :role,
      :sets,
      :reps,
      :volume
    ])
    |> validate_required([
      :workout_session_id,
      :muscle_token,
      :muscle_name,
      :role,
      :sets,
      :reps,
      :volume
    ])
    |> validate_inclusion(:role, ["primary", "secondary"])
    |> validate_number(:sets, greater_than_or_equal_to: 0)
    |> validate_number(:reps, greater_than_or_equal_to: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:workout_session_id)
    |> check_constraint(:role, name: :workout_muscle_summaries_role_check)
    |> check_constraint(:sets, name: :workout_muscle_summaries_sets_check)
    |> check_constraint(:reps, name: :workout_muscle_summaries_reps_check)
    |> check_constraint(:volume, name: :workout_muscle_summaries_volume_check)
    |> unique_constraint([:workout_session_id, :muscle_token, :role],
      name: :workout_muscle_summaries_workout_token_role_idx
    )
  end
end
