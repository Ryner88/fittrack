defmodule Fittrack.Training.WorkoutPlan do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutPlanExercise

  schema "workout_plans" do
    field :name, :string
    field :description, :string

    belongs_to :user, User
    has_many :workout_plan_exercises, WorkoutPlanExercise, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_plan, attrs) do
    workout_plan
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> update_change(:description, &String.trim/1)
    |> unique_constraint([:user_id, :name])
    |> cast_assoc(:workout_plan_exercises, with: &WorkoutPlanExercise.changeset/2)
  end
end
