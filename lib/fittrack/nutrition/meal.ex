defmodule Fittrack.Nutrition.Meal do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Nutrition.MealItem

  schema "meals" do
    field :name, :string
    field :eaten_at, :utc_datetime
    field :notes, :string
    field :total_calories, :decimal
    field :total_protein_g, :decimal
    field :total_carbs_g, :decimal
    field :total_fats_g, :decimal

    belongs_to :user, Fittrack.Accounts.User
    has_many :meal_items, MealItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meal, attrs) do
    meal
    |> cast(attrs, [
      :name,
      :eaten_at,
      :notes,
      :total_calories,
      :total_protein_g,
      :total_carbs_g,
      :total_fats_g,
      :user_id
    ])
    |> validate_required([:name, :eaten_at, :user_id])
    |> validate_number(:total_calories, greater_than_or_equal_to: 0)
    |> validate_number(:total_protein_g, greater_than_or_equal_to: 0)
    |> validate_number(:total_carbs_g, greater_than_or_equal_to: 0)
    |> validate_number(:total_fats_g, greater_than_or_equal_to: 0)
  end
end
