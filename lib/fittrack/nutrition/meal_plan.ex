defmodule Fittrack.Nutrition.MealPlan do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Nutrition.MealPlanMeal

  schema "meal_plans" do
    field :name, :string
    field :description, :string
    field :goal, :string
    field :daily_calories_target, :integer
    field :daily_protein_g_target, :integer
    field :daily_carbs_g_target, :integer
    field :daily_fats_g_target, :integer

    belongs_to :user, Fittrack.Accounts.User
    has_many :meal_plan_meals, MealPlanMeal

    timestamps(type: :utc_datetime)
  end

  @goals ["maintain", "bulk", "cut"]

  @doc false
  def changeset(meal_plan, attrs) do
    meal_plan
    |> cast(attrs, [
      :name,
      :description,
      :goal,
      :daily_calories_target,
      :daily_protein_g_target,
      :daily_carbs_g_target,
      :daily_fats_g_target,
      :user_id
    ])
    |> validate_required([:name, :goal, :user_id])
    |> validate_inclusion(:goal, @goals)
    |> validate_number(:daily_calories_target, greater_than: 0)
    |> validate_number(:daily_protein_g_target, greater_than_or_equal_to: 0)
    |> validate_number(:daily_carbs_g_target, greater_than_or_equal_to: 0)
    |> validate_number(:daily_fats_g_target, greater_than_or_equal_to: 0)
    |> cast_assoc(:meal_plan_meals,
      with: &MealPlanMeal.changeset/2,
      required: false,
      on_replace: :delete
    )
  end

  def goals, do: @goals
end
