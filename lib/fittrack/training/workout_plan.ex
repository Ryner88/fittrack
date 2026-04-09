defmodule Fittrack.Training.WorkoutPlan do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User
  alias Fittrack.Training.WorkoutPlanExercise

  @goal_preferences ~w(strength hypertrophy endurance fat_loss general)
  @primary_styles ~w(bodybuilding powerlifting powerbuilding strength hypertrophy conditioning athletic olympic_weightlifting calisthenics mobility rehab beginner)
  @training_style_preferences ~w(cardio strength hypertrophy isometric speed power plyometric mobility conditioning core balance functional bodybuilding calisthenics)
  @training_split_preferences ~w(full_body upper_lower push_pull_legs body_part_split athletic_performance circuit_based strength_focused hybrid)
  @difficulty_levels ~w(beginner intermediate advanced)

  schema "workout_plans" do
    field :name, :string
    field :description, :string
    field :goal, :string

    field :primary_style, :string
    field :secondary_style_tags, {:array, :string}, default: []
    field :primary_goal, :string
    field :secondary_goal, :string
    field :tertiary_goal, :string
    field :additional_goal, :string
    field :training_styles, {:array, :string}, default: []
    field :training_split, {:array, :string}, default: []
    field :difficulty, :string
    field :estimated_duration_minutes, :integer

    belongs_to :user, User
    has_many :workout_plan_exercises, WorkoutPlanExercise, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_plan, attrs) do
    workout_plan
    |> cast(attrs, [
      :name,
      :description,
      :goal,
      :primary_style,
      :secondary_style_tags,
      :primary_goal,
      :secondary_goal,
      :tertiary_goal,
      :additional_goal,
      :training_styles,
      :training_split,
      :difficulty,
      :estimated_duration_minutes
    ])
    |> validate_required([:name])
    |> validate_inclusion(:primary_style, @primary_styles)
    |> validate_inclusion(:difficulty, @difficulty_levels)
    |> validate_number(:estimated_duration_minutes, greater_than: 0)
    |> validate_array_subset(:secondary_style_tags, @primary_styles)
    |> validate_array_subset(:training_styles, @training_style_preferences)
    |> validate_array_subset(:training_split, @training_split_preferences)
    |> validate_optional_inclusion(:primary_goal, @goal_preferences)
    |> validate_optional_inclusion(:secondary_goal, @goal_preferences)
    |> validate_optional_inclusion(:tertiary_goal, @goal_preferences)
    |> validate_optional_inclusion(:additional_goal, @goal_preferences)
    |> validate_unique_goals([:primary_goal, :secondary_goal, :tertiary_goal, :additional_goal])
    |> update_change(:name, &String.trim/1)
    |> update_change(:description, &String.trim/1)
    |> unique_constraint([:user_id, :name])
    |> cast_assoc(:workout_plan_exercises, with: &WorkoutPlanExercise.changeset/2)
  end

  defp validate_optional_inclusion(changeset, field, allowed_values) do
    value = get_field(changeset, field)

    cond do
      is_nil(value) ->
        changeset

      value in allowed_values ->
        changeset

      true ->
        add_error(changeset, field, "is invalid")
    end
  end

  defp validate_unique_goals(changeset, fields) do
    duplicates =
      fields
      |> Enum.map(&{&1, get_field(changeset, &1)})
      |> Enum.reject(fn {_field, value} -> is_nil(value) end)
      |> Enum.group_by(fn {_field, value} -> value end, fn {field, _value} -> field end)
      |> Enum.filter(fn {_value, duplicate_fields} -> length(duplicate_fields) > 1 end)

    Enum.reduce(duplicates, changeset, fn {_value, duplicate_fields}, acc ->
      Enum.reduce(duplicate_fields, acc, fn field, nested_acc ->
        add_error(nested_acc, field, "must be unique")
      end)
    end)
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
