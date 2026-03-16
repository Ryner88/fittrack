defmodule Fittrack.Training.WorkoutPlan do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutPlanExercise

  schema "workout_plans" do
    field :name, :string
    field :description, :string

    field :primary_style, :string
    field :secondary_style_tags, {:array, :string}, default: []
    field :goal, :string
    field :difficulty, :string
    field :estimated_duration_minutes, :integer

    belongs_to :user, User
    has_many :workout_plan_exercises, WorkoutPlanExercise, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @training_styles ~w(bodybuilding powerlifting powerbuilding strength hypertrophy conditioning athletic olympic_weightlifting calisthenics mobility rehab beginner)
  @difficulty_levels ~w(beginner intermediate advanced)

  @doc false
  def changeset(workout_plan, attrs) do
    workout_plan
    |> cast(attrs, [
      :name,
      :description,
      :primary_style,
      :secondary_style_tags,
      :goal,
      :difficulty,
      :estimated_duration_minutes
    ])
    |> validate_required([:name])
    |> validate_inclusion(:primary_style, @training_styles)
    |> validate_inclusion(:difficulty, @difficulty_levels)
    |> validate_number(:estimated_duration_minutes, greater_than: 0)
    |> validate_array_subset(:secondary_style_tags, @training_styles)
    |> update_change(:name, &String.trim/1)
    |> update_change(:description, &String.trim/1)
    |> unique_constraint([:user_id, :name])
    |> cast_assoc(:workout_plan_exercises, with: &WorkoutPlanExercise.changeset/2)
  end

  defp validate_array_subset(changeset, field, allowed_values) do
    values = get_field(changeset, field, [])

    if Enum.all?(values, &(&1 in allowed_values)) do
      changeset
    else
      add_error(changeset, field, "contains invalid values")
    end
  end
end
