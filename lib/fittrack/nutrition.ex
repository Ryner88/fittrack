defmodule Fittrack.Nutrition do
  @moduledoc """
  The Nutrition context.
  """

  import Ecto.Query, warn: false

  alias Fittrack.Accounts.Scope
  alias Ecto.Multi
  alias Fittrack.Repo
  alias Fittrack.Nutrition.Meal
  alias Fittrack.Nutrition.MealItem
  alias Fittrack.Nutrition.MealPlan
  alias Fittrack.Nutrition.MealPlanMeal
  alias Fittrack.Nutrition.Food

  @doc """
  Returns the list of meals for the current user.
  """
  def list_meals(scope, opts \\ %{})

  def list_meals(%Scope{user: user}, opts) do
    date = Map.get(opts, :date)
    limit = Map.get(opts, :limit, 50)

    Meal
    |> where([meal], meal.user_id == ^user.id)
    |> maybe_filter_by_date(date)
    |> order_by([meal], desc: meal.eaten_at)
    |> limit(^limit)
    |> preload(:meal_items)
    |> Repo.all()
  end

  def list_meals(_, _opts), do: []

  @doc """
  Returns the list of foods in the library for the current user.
  """
  def list_foods(%Scope{user: user}) do
    Food
    |> where([food], food.user_id == ^user.id)
    |> order_by([food], asc: food.name)
    |> Repo.all()
  end

  def list_foods(_), do: []

  @doc """
  Gets a single food item for the current user.
  """
  def get_food!(%Scope{user: user}, id) do
    Repo.get_by!(Food, id: id, user_id: user.id)
  end

  def get_food(%Scope{user: user}, id) do
    Repo.get_by(Food, id: id, user_id: user.id)
  end

  @doc """
  Creates a food record for the current user.
  """
  def create_food(%Scope{user: user}, attrs) do
    attrs = Map.put(attrs, "user_id", user.id)

    %Food{}
    |> Food.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a food record.
  """
  def update_food(%Scope{}, %Food{} = food, attrs) do
    food
    |> Food.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a food record.
  """
  def delete_food(%Scope{}, %Food{} = food) do
    Repo.delete(food)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking food changes.
  """
  def change_food(%Food{} = food, attrs \\ %{}) do
    Food.changeset(food, attrs)
  end

  @doc """
  Calculates totals for meal items.
  """
  def calculate_meal_totals(meal_items) when is_list(meal_items) do
    Enum.reduce(
      meal_items,
      %{
        total_calories: Decimal.new(0),
        total_protein_g: Decimal.new(0),
        total_carbs_g: Decimal.new(0),
        total_fats_g: Decimal.new(0)
      },
      fn item, acc ->
        calories = item[:calories] || item["calories"] || Decimal.new(0)
        protein = item[:protein_g] || item["protein_g"] || Decimal.new(0)
        carbs = item[:carbs_g] || item["carbs_g"] || Decimal.new(0)
        fats = item[:fats_g] || item["fats_g"] || Decimal.new(0)

        %{
          total_calories: Decimal.add(acc.total_calories, Decimal.new(calories)),
          total_protein_g: Decimal.add(acc.total_protein_g, Decimal.new(protein)),
          total_carbs_g: Decimal.add(acc.total_carbs_g, Decimal.new(carbs)),
          total_fats_g: Decimal.add(acc.total_fats_g, Decimal.new(fats))
        }
      end
    )
  end

  @doc """
  Builds a meal item map from food + quantity.
  """
  def build_meal_item_from_food(%Scope{} = scope, food_id, quantity) do
    with %Food{} = food <- get_food(scope, food_id),
         qty when not is_nil(qty) <- cast_decimal(quantity) do
      factor =
        if Decimal.compare(food.unit_amount, 0) == :gt,
          do: Decimal.div(qty, food.unit_amount),
          else: Decimal.new(0)

      %{
        food_id: food.id,
        food_name: food.name,
        unit: food.unit,
        quantity: qty,
        calories: Decimal.mult(food.calories_per_unit, factor) |> Decimal.round(2),
        protein_g: Decimal.mult(food.protein_per_unit, factor) |> Decimal.round(2),
        carbs_g: Decimal.mult(food.carbs_per_unit, factor) |> Decimal.round(2),
        fats_g: Decimal.mult(food.fats_per_unit, factor) |> Decimal.round(2)
      }
    else
      _ -> nil
    end
  end

  @doc """
  Gets a single meal for the current user.
  """
  def get_meal!(%Scope{user: user}, id) do
    Repo.get_by!(Meal, id: id, user_id: user.id)
    |> Repo.preload(:meal_items)
  end

  def get_meal(%Scope{user: user}, id) do
    Repo.get_by(Meal, id: id, user_id: user.id)
    |> Repo.preload(:meal_items)
  end

  @doc """
  Creates a meal scoped to the current user.
  """
  def create_meal(%Scope{user: user}, attrs) do
    meal_items = Map.get(attrs, "meal_items", [])
    totals = calculate_meal_totals(meal_items)

    attrs =
      attrs
      |> Map.merge(%{
        "total_calories" => totals.total_calories,
        "total_protein_g" => totals.total_protein_g,
        "total_carbs_g" => totals.total_carbs_g,
        "total_fats_g" => totals.total_fats_g
      })
      |> Map.put("user_id", user.id)
      |> Map.delete("meal_items")

    Multi.new()
    |> Multi.insert(:meal, Meal.changeset(%Meal{}, attrs))
    |> persist_meal_items(:meal_items, meal_items)
    |> Repo.transaction()
    |> case do
      {:ok, %{meal: meal}} -> {:ok, Repo.preload(meal, :meal_items)}
      {:error, :meal, changeset, _changes} -> {:error, changeset}
      {:error, :meal_items, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Updates a meal.
  """
  def update_meal(%Scope{}, %Meal{} = meal, attrs) do
    meal_items = Map.get(attrs, "meal_items", [])
    totals = calculate_meal_totals(meal_items)

    attrs =
      attrs
      |> Map.merge(%{
        "total_calories" => totals.total_calories,
        "total_protein_g" => totals.total_protein_g,
        "total_carbs_g" => totals.total_carbs_g,
        "total_fats_g" => totals.total_fats_g
      })
      |> Map.delete("meal_items")

    Multi.new()
    |> Multi.update(:meal, Meal.changeset(meal, attrs))
    |> Multi.delete_all(
      :delete_meal_items,
      from(meal_item in MealItem, where: meal_item.meal_id == ^meal.id)
    )
    |> persist_meal_items(:meal_items, meal_items)
    |> Repo.transaction()
    |> case do
      {:ok, %{meal: updated_meal}} -> {:ok, Repo.preload(updated_meal, :meal_items)}
      {:error, :meal, changeset, _changes} -> {:error, changeset}
      {:error, :meal_items, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a meal.
  """
  def delete_meal(%Scope{}, %Meal{} = meal) do
    Repo.delete(meal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meal changes.
  """
  def change_meal(%Meal{} = meal, attrs \\ %{}) do
    Meal.changeset(meal, attrs)
  end

  @doc """
  Creates a meal item for a meal.
  """
  def create_meal_item(%Scope{}, %Meal{} = meal, attrs) do
    %MealItem{}
    |> MealItem.changeset(attrs)
    |> Ecto.Changeset.put_change(:meal_id, meal.id)
    |> Repo.insert()
  end

  @doc """
  Updates a meal item.
  """
  def update_meal_item(%Scope{}, %MealItem{} = meal_item, attrs) do
    meal_item
    |> MealItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meal item.
  """
  def delete_meal_item(%Scope{}, %MealItem{} = meal_item) do
    Repo.delete(meal_item)
  end

  @doc """
  Deletes all meal items for a meal.
  """
  def delete_meal_items_for_meal(%Scope{} = _scope, %Meal{} = meal) do
    from(mi in MealItem, where: mi.meal_id == ^meal.id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meal item changes.
  """
  def change_meal_item(%MealItem{} = meal_item, attrs \\ %{}) do
    MealItem.changeset(meal_item, attrs)
  end

  @doc """
  Returns the list of meal plans for the current user.
  """
  def list_meal_plans(scope)

  def list_meal_plans(%Scope{user: user}) do
    MealPlan
    |> where([plan], plan.user_id == ^user.id)
    |> order_by([plan], desc: plan.updated_at)
    |> preload(meal_plan_meals: [])
    |> Repo.all()
  end

  def list_meal_plans(_), do: []

  @doc """
  Gets a single meal plan for the current user.
  """
  def get_meal_plan!(%Scope{user: user}, id) do
    Repo.get_by!(MealPlan, id: id, user_id: user.id)
    |> Repo.preload(meal_plan_meals: [])
  end

  def get_meal_plan(%Scope{user: user}, id) do
    Repo.get_by(MealPlan, id: id, user_id: user.id)
    |> Repo.preload(meal_plan_meals: [])
  end

  @doc """
  Creates a meal plan scoped to the current user.
  """
  def create_meal_plan(%Scope{user: user}, attrs) do
    attrs = Map.put(attrs, "user_id", user.id)

    %MealPlan{}
    |> MealPlan.changeset(attrs)
    |> Repo.insert()
    |> preload_meal_plan()
  end

  @doc """
  Updates a meal plan.
  """
  def update_meal_plan(%Scope{}, %MealPlan{} = meal_plan, attrs) do
    meal_plan
    |> MealPlan.changeset(attrs)
    |> Repo.update()
    |> preload_meal_plan()
  end

  @doc """
  Deletes a meal plan.
  """
  def delete_meal_plan(%Scope{}, %MealPlan{} = meal_plan) do
    Repo.delete(meal_plan)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meal plan changes.
  """
  def change_meal_plan(%MealPlan{} = meal_plan, attrs \\ %{}) do
    MealPlan.changeset(meal_plan, attrs)
  end

  @doc """
  Creates a meal plan meal for a meal plan.
  """
  def create_meal_plan_meal(%Scope{}, %MealPlan{} = meal_plan, attrs) do
    %MealPlanMeal{}
    |> MealPlanMeal.changeset(attrs)
    |> Ecto.Changeset.put_change(:meal_plan_id, meal_plan.id)
    |> Repo.insert()
  end

  @doc """
  Updates a meal plan meal.
  """
  def update_meal_plan_meal(%Scope{}, %MealPlanMeal{} = meal_plan_meal, attrs) do
    meal_plan_meal
    |> MealPlanMeal.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meal plan meal.
  """
  def delete_meal_plan_meal(%Scope{}, %MealPlanMeal{} = meal_plan_meal) do
    Repo.delete(meal_plan_meal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meal plan meal changes.
  """
  def change_meal_plan_meal(%MealPlanMeal{} = meal_plan_meal, attrs \\ %{}) do
    MealPlanMeal.changeset(meal_plan_meal, attrs)
  end

  defp persist_meal_items(multi, step_name, meal_items) do
    Multi.run(multi, step_name, fn repo, %{meal: meal} ->
      Enum.reduce_while(meal_items, {:ok, []}, fn attrs, {:ok, inserted_items} ->
        attrs = put_meal_id(normalize_meal_item_attrs(attrs), meal.id)

        case %MealItem{} |> MealItem.changeset(attrs) |> repo.insert() do
          {:ok, meal_item} -> {:cont, {:ok, [meal_item | inserted_items]}}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
      end)
    end)
  end

  defp normalize_meal_item_attrs(attrs) when is_map(attrs) do
    attrs
    |> rename_meal_item_key("meal_name", "food_name")
    |> rename_meal_item_key(:meal_name, :food_name)
  end

  defp put_meal_id(attrs, meal_id) do
    cond do
      Enum.any?(Map.keys(attrs), &is_binary/1) -> Map.put(attrs, "meal_id", meal_id)
      true -> Map.put(attrs, :meal_id, meal_id)
    end
  end

  defp rename_meal_item_key(attrs, from, to) do
    case Map.fetch(attrs, from) do
      {:ok, value} -> attrs |> Map.put(to, value) |> Map.delete(from)
      :error -> attrs
    end
  end

  defp cast_decimal(nil), do: Decimal.new(0)
  defp cast_decimal(value) when is_struct(value, Decimal), do: value
  defp cast_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp cast_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp cast_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp cast_decimal(_), do: nil

  defp preload_meal_plan({:ok, meal_plan}), do: {:ok, Repo.preload(meal_plan, :meal_plan_meals)}
  defp preload_meal_plan(other), do: other

  @doc """
  Returns nutrition stats for the current user.
  """
  def get_nutrition_stats(%Scope{user: user}, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    from(meal in Meal,
      where: meal.user_id == ^user.id,
      where: meal.eaten_at >= ^start_of_day,
      where: meal.eaten_at <= ^end_of_day,
      select: %{
        total_calories: sum(meal.total_calories),
        total_protein_g: sum(meal.total_protein_g),
        total_carbs_g: sum(meal.total_carbs_g),
        total_fats_g: sum(meal.total_fats_g)
      }
    )
    |> Repo.one()
    |> case do
      nil -> %{total_calories: 0, total_protein_g: 0, total_carbs_g: 0, total_fats_g: 0}
      result -> result
    end
  end

  @doc """
  Returns nutrition data over time for charts.
  """
  def nutrition_over_time(%Scope{user: user}, days \\ 30) do
    start_date = Date.utc_today() |> Date.add(-days)

    from(meal in Meal,
      where: meal.user_id == ^user.id,
      where: fragment("DATE(?) >= ?", meal.eaten_at, ^start_date),
      group_by: fragment("DATE(?)", meal.eaten_at),
      order_by: fragment("DATE(?)", meal.eaten_at),
      select: %{
        date: fragment("DATE(?)", meal.eaten_at),
        calories: sum(meal.total_calories),
        protein: sum(meal.total_protein_g),
        carbs: sum(meal.total_carbs_g),
        fats: sum(meal.total_fats_g)
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns meal plan for a specific day of the week.
  """
  def get_meal_plan_for_day(%Scope{user: user}, day_of_week) do
    MealPlan
    |> where([plan], plan.user_id == ^user.id)
    |> join(:inner, [plan], meals in assoc(plan, :meal_plan_meals),
      on: meals.day_of_week == ^day_of_week
    )
    |> preload([:meal_plan_meals])
    |> Repo.all()
  end

  # Private helpers

  defp maybe_filter_by_date(query, nil), do: query

  defp maybe_filter_by_date(query, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    where(query, [meal], meal.eaten_at >= ^start_of_day and meal.eaten_at <= ^end_of_day)
  end
end
