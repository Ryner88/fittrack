defmodule Fittrack.Nutrition.Food do
  use Ecto.Schema
  import Ecto.Changeset

  alias Fittrack.Accounts.User

  schema "foods" do
    field :name, :string
    field :unit, :string, default: "g"
    field :unit_amount, :decimal, default: Decimal.new("100.0")
    field :calories_per_unit, :decimal
    field :protein_per_unit, :decimal
    field :carbs_per_unit, :decimal
    field :fats_per_unit, :decimal
    field :fiber_per_unit, :decimal
    field :sugar_per_unit, :decimal
    field :sodium_mg_per_unit, :decimal
    field :micronutrients, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(food, attrs) do
    food
    |> cast(attrs, [
      :name,
      :unit,
      :unit_amount,
      :calories_per_unit,
      :protein_per_unit,
      :carbs_per_unit,
      :fats_per_unit,
      :fiber_per_unit,
      :sugar_per_unit,
      :sodium_mg_per_unit,
      :micronutrients,
      :user_id
    ])
    |> validate_required([:name, :unit, :unit_amount, :calories_per_unit, :user_id])
    |> validate_number(:unit_amount, greater_than: 0)
    |> validate_number(:calories_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:protein_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:carbs_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:fats_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:fiber_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:sugar_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:sodium_mg_per_unit, greater_than_or_equal_to: 0)
  end
end
