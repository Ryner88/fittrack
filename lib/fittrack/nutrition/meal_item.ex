defmodule Fittrack.Nutrition.MealItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Nutrition.Meal

  schema "meal_items" do
    field :quantity, :decimal
    field :unit, :string
    field :calories, :decimal
    field :protein_g, :decimal
    field :carbs_g, :decimal
    field :fats_g, :decimal
    field :fiber_g, :decimal
    field :sugar_g, :decimal
    field :sodium_mg, :decimal
    field :micronutrients, :map, default: %{}
    field :source_image_metadata, :map, default: %{}
    field :parsed_values, :map, default: %{}
    field :food_name, :string

    belongs_to :meal, Meal
    belongs_to :food, Fittrack.Nutrition.Food

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meal_item, attrs) do
    meal_item
    |> cast(attrs, [
      :quantity,
      :unit,
      :calories,
      :protein_g,
      :carbs_g,
      :fats_g,
      :fiber_g,
      :sugar_g,
      :sodium_mg,
      :micronutrients,
      :source_image_metadata,
      :parsed_values,
      :food_name,
      :meal_id,
      :food_id
    ])
    |> validate_required([:quantity, :unit, :food_name, :meal_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:calories, greater_than_or_equal_to: 0)
    |> validate_number(:protein_g, greater_than_or_equal_to: 0)
    |> validate_number(:carbs_g, greater_than_or_equal_to: 0)
    |> validate_number(:fats_g, greater_than_or_equal_to: 0)
    |> validate_number(:fiber_g, greater_than_or_equal_to: 0)
    |> validate_number(:sugar_g, greater_than_or_equal_to: 0)
    |> validate_number(:sodium_mg, greater_than_or_equal_to: 0)
  end
end
