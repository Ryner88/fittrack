defmodule Fittrack.Nutrition do
  @moduledoc """
  The Nutrition context.
  """

  import Ecto.Query, warn: false

  alias Fittrack.Accounts.Scope
  alias Fittrack.Repo
  alias Fittrack.Nutrition.Meal
  alias Fittrack.Nutrition.MealItem
  alias Fittrack.Nutrition.MealPlan
  alias Fittrack.Nutrition.MealPlanMeal
  alias Fittrack.Nutrition.Food
  alias Fittrack.Nutrition.ScreenshotImportParser
  alias Fittrack.Nutrition.UrlImportParser

  @open_food_facts_url "https://world.openfoodfacts.org/api/v2/product"
  @open_food_facts_fields [
    "code",
    "product_name",
    "product_name_en",
    "serving_size",
    "nutriments",
    "nutrition_data_per"
  ]

  @doc """
  Returns the list of meals for the current user.
  """
  def list_meals(scope, opts \\ %{})

  def list_meals(%Scope{user: user}, opts) do
    date = Map.get(opts, :date)
    limit = Map.get(opts, :limit, 50)
    search = Map.get(opts, :search)

    Meal
    |> where([meal], meal.user_id == ^user.id)
    |> maybe_filter_by_date(date)
    |> maybe_filter_meals_by_search(search)
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
  Looks up food nutrition data from a barcode import provider.
  """
  def lookup_food_by_barcode(barcode) when is_binary(barcode) do
    barcode = String.trim(barcode)

    cond do
      barcode == "" ->
        {:error, :blank_barcode}

      not String.match?(barcode, ~r/^\d+$/) ->
        {:error, :invalid_barcode}

      true ->
        fetch_food_by_barcode(barcode)
    end
  end

  def lookup_food_by_barcode(_), do: {:error, :invalid_barcode}

  @doc """
  Imports nutrition data from a supported dining-site URL.
  """
  def import_food_from_url(url), do: UrlImportParser.parse(url)

  def supported_url_import_hosts, do: UrlImportParser.supported_hosts()

  def import_food_from_screenshot(data_url), do: ScreenshotImportParser.parse_image_data(data_url)

  @doc """
  Builds a meal item map from arbitrary nutrition attributes.
  """
  def build_meal_item(attrs) when is_map(attrs) do
    quantity = to_decimal(attrs[:quantity] || attrs["quantity"])
    unit_amount = to_decimal(attrs[:unit_amount] || attrs["unit_amount"])
    food_name = attrs[:food_name] || attrs["food_name"] || attrs[:name] || attrs["name"]
    unit = attrs[:unit] || attrs["unit"] || "g"

    with true <- present_decimal?(quantity),
         true <- present_decimal?(unit_amount),
         true <- is_binary(food_name),
         true <- String.trim(food_name) != "" do
      factor = Decimal.div(quantity, unit_amount)

      %{
        food_id: attrs[:food_id] || attrs["food_id"],
        food_name: String.trim(food_name),
        unit: unit,
        quantity: quantity,
        micronutrients:
          parse_micronutrients(
            attrs[:micronutrients] || attrs["micronutrients"] || attrs[:micronutrients_text] ||
              attrs["micronutrients_text"]
          ),
        calories:
          Decimal.mult(
            to_decimal(attrs[:calories_per_unit] || attrs["calories_per_unit"]),
            factor
          )
          |> Decimal.round(2),
        protein_g:
          Decimal.mult(to_decimal(attrs[:protein_per_unit] || attrs["protein_per_unit"]), factor)
          |> Decimal.round(2),
        carbs_g:
          Decimal.mult(to_decimal(attrs[:carbs_per_unit] || attrs["carbs_per_unit"]), factor)
          |> Decimal.round(2),
        fats_g:
          Decimal.mult(to_decimal(attrs[:fats_per_unit] || attrs["fats_per_unit"]), factor)
          |> Decimal.round(2),
        fiber_g:
          Decimal.mult(to_decimal(attrs[:fiber_per_unit] || attrs["fiber_per_unit"]), factor)
          |> Decimal.round(2),
        sugar_g:
          Decimal.mult(to_decimal(attrs[:sugar_per_unit] || attrs["sugar_per_unit"]), factor)
          |> Decimal.round(2),
        sodium_mg:
          Decimal.mult(
            to_decimal(attrs[:sodium_mg_per_unit] || attrs["sodium_mg_per_unit"]),
            factor
          )
          |> Decimal.round(2)
      }
    else
      _ -> nil
    end
  end

  def build_meal_item(_), do: nil

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
        calories = to_decimal(item[:calories] || item["calories"])
        protein = to_decimal(item[:protein_g] || item["protein_g"])
        carbs = to_decimal(item[:carbs_g] || item["carbs_g"])
        fats = to_decimal(item[:fats_g] || item["fats_g"])

        %{
          total_calories: Decimal.add(acc.total_calories, calories),
          total_protein_g: Decimal.add(acc.total_protein_g, protein),
          total_carbs_g: Decimal.add(acc.total_carbs_g, carbs),
          total_fats_g: Decimal.add(acc.total_fats_g, fats)
        }
      end
    )
  end

  @doc """
  Builds a meal item map from food + quantity.
  """
  def build_meal_item_from_food(%Scope{} = scope, food_id, quantity) do
    with %Food{} = food <- get_food(scope, food_id),
         %{} = item <-
           build_meal_item(%{
             food_id: food.id,
             food_name: food.name,
             unit: food.unit,
             unit_amount: food.unit_amount,
             quantity: quantity,
             calories_per_unit: food.calories_per_unit,
             protein_per_unit: food.protein_per_unit,
             carbs_per_unit: food.carbs_per_unit,
             fats_per_unit: food.fats_per_unit,
             fiber_per_unit: food.fiber_per_unit,
             sugar_per_unit: food.sugar_per_unit,
             sodium_mg_per_unit: food.sodium_mg_per_unit,
             micronutrients: food.micronutrients
           }) do
      Map.put(item, :food_id, food.id)
    else
      _ -> nil
    end
  end

  @doc """
  Builds a food payload suitable for manual confirmation after barcode lookup.
  """
  def barcode_food_defaults(%{} = attrs) do
    %{
      "barcode" => attrs[:barcode] || attrs["barcode"] || "",
      "name" => attrs[:name] || attrs["name"] || "",
      "unit" => attrs[:unit] || attrs["unit"] || "g",
      "unit_amount" => decimal_string(attrs[:unit_amount] || attrs["unit_amount"] || 100),
      "quantity" => decimal_string(attrs[:quantity] || attrs["quantity"] || 100),
      "calories_per_unit" =>
        decimal_string(attrs[:calories_per_unit] || attrs["calories_per_unit"] || 0),
      "protein_per_unit" =>
        decimal_string(attrs[:protein_per_unit] || attrs["protein_per_unit"] || 0),
      "carbs_per_unit" => decimal_string(attrs[:carbs_per_unit] || attrs["carbs_per_unit"] || 0),
      "fats_per_unit" => decimal_string(attrs[:fats_per_unit] || attrs["fats_per_unit"] || 0),
      "fiber_per_unit" => decimal_string(attrs[:fiber_per_unit] || attrs["fiber_per_unit"] || 0),
      "sugar_per_unit" => decimal_string(attrs[:sugar_per_unit] || attrs["sugar_per_unit"] || 0),
      "sodium_mg_per_unit" =>
        decimal_string(attrs[:sodium_mg_per_unit] || attrs["sodium_mg_per_unit"] || 0),
      "micronutrients_text" =>
        micronutrients_to_text(attrs[:micronutrients] || attrs["micronutrients"] || %{})
    }
  end

  def barcode_food_defaults(_), do: barcode_food_defaults(%{})

  defp fetch_food_by_barcode(barcode) do
    headers = [{"user-agent", "Fittrack/0.1 barcode-import (contact: local-app)"}]
    params = [fields: Enum.join(@open_food_facts_fields, ",")]
    url = "#{@open_food_facts_url}/#{barcode}"

    case barcode_lookup_client().get(url, headers: headers, params: params) do
      {:ok, %{status: 200, body: %{"status" => 1, "product" => product}}} ->
        {:ok, normalize_barcode_product(barcode, product)}

      {:ok, %{status: 200, body: %{"status" => 0}}} ->
        {:error, :not_found}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: _status}} ->
        {:error, :lookup_failed}

      {:error, _error} ->
        {:error, :lookup_failed}
    end
  end

  defp normalize_barcode_product(barcode, product) do
    nutriments = product["nutriments"] || %{}
    measurement = choose_barcode_measurement(product, nutriments)

    %{
      "barcode" => barcode,
      "name" => product["product_name"] || product["product_name_en"] || "Imported product",
      "unit" => measurement.unit,
      "unit_amount" => decimal_string(measurement.unit_amount),
      "quantity" => decimal_string(measurement.unit_amount),
      "calories_per_unit" =>
        decimal_string(barcode_nutriment(nutriments, measurement.type, ["energy-kcal", "energy"])),
      "protein_per_unit" =>
        decimal_string(barcode_nutriment(nutriments, measurement.type, ["proteins"])),
      "carbs_per_unit" =>
        decimal_string(barcode_nutriment(nutriments, measurement.type, ["carbohydrates"])),
      "fats_per_unit" => decimal_string(barcode_nutriment(nutriments, measurement.type, ["fat"]))
    }
  end

  defp choose_barcode_measurement(product, nutriments) do
    per_100g_available? =
      Enum.any?(["energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g"], fn key ->
        not is_nil(nutriments[key])
      end)

    cond do
      per_100g_available? ->
        %{type: :per_100g, unit: "g", unit_amount: Decimal.new(100)}

      true ->
        serving_size = product["serving_size"]
        parsed_serving = parse_serving_size(serving_size)

        %{
          type: :per_serving,
          unit: parsed_serving.unit,
          unit_amount: parsed_serving.unit_amount
        }
    end
  end

  defp parse_serving_size(serving_size) when is_binary(serving_size) do
    case Regex.run(~r/(\d+(?:[.,]\d+)?)\s*([[:alpha:]]+)/u, serving_size) do
      [_, amount, unit] ->
        %{unit: String.downcase(unit), unit_amount: to_decimal(String.replace(amount, ",", "."))}

      _ ->
        %{unit: "serving", unit_amount: Decimal.new(1)}
    end
  end

  defp parse_serving_size(_), do: %{unit: "serving", unit_amount: Decimal.new(1)}

  defp barcode_nutriment(nutriments, :per_100g, keys) do
    barcode_nutriment_value(nutriments, Enum.map(keys, &"#{&1}_100g") ++ keys)
  end

  defp barcode_nutriment(nutriments, :per_serving, keys) do
    barcode_nutriment_value(nutriments, Enum.map(keys, &"#{&1}_serving") ++ keys)
  end

  defp barcode_nutriment_value(nutriments, keys) do
    Enum.find_value(keys, Decimal.new(0), fn key ->
      value = nutriments[key]

      if is_nil(value), do: false, else: to_decimal(value)
    end)
  end

  defp barcode_lookup_client do
    Application.get_env(:fittrack, :barcode_lookup_http_client, Req)
  end

  defp present_decimal?(%Decimal{} = value), do: Decimal.compare(value, 0) == :gt

  defp present_decimal?(_), do: false

  defp decimal_string(value) do
    value
    |> to_decimal()
    |> Decimal.round(2)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  def micronutrients_to_text(micronutrients) when is_map(micronutrients) do
    micronutrients
    |> Enum.map(fn {name, value} -> "#{name}: #{value}" end)
    |> Enum.join("\n")
  end

  def micronutrients_to_text(_), do: ""

  def parse_micronutrients(nil), do: %{}
  def parse_micronutrients(micronutrients) when is_map(micronutrients), do: micronutrients

  def parse_micronutrients(micronutrients) when is_binary(micronutrients) do
    micronutrients
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [name, value] -> Map.put(acc, String.trim(name), String.trim(value))
        _ -> acc
      end
    end)
  end

  def parse_micronutrients(_), do: %{}

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
    attrs
    |> Map.put("user_id", user.id)
    |> persist_meal(%Meal{})
  end

  @doc """
  Updates a meal.
  """
  def update_meal(%Scope{}, %Meal{} = meal, attrs) do
    persist_meal(attrs, meal)
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
    |> MealItem.changeset(Map.put(attrs, "meal_id", meal.id))
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
  end

  @doc """
  Updates a meal plan.
  """
  def update_meal_plan(%Scope{}, %MealPlan{} = meal_plan, attrs) do
    meal_plan
    |> MealPlan.changeset(attrs)
    |> Repo.update()
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
    |> normalize_stat_map()
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
    |> fill_nutrition_dates(start_date, Date.utc_today())
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

  @doc """
  Returns meals in a date range for the current user.
  """
  def list_meals_in_date_range(%Scope{user: user}, %Date{} = start_date, %Date{} = end_date) do
    from(meal in Meal,
      where: meal.user_id == ^user.id,
      where: fragment("DATE(?)", meal.eaten_at) >= ^start_date,
      where: fragment("DATE(?)", meal.eaten_at) <= ^end_date,
      order_by: [asc: meal.eaten_at]
    )
    |> Repo.all()
    |> Repo.preload(:meal_items)
  end

  def list_meals_in_date_range(_, _start_date, _end_date), do: []

  @doc """
  Builds a weekly overview for the nutrition dashboard.
  """
  def weekly_nutrition_overview(%Scope{} = scope, reference_date \\ Date.utc_today()) do
    start_date = Date.beginning_of_week(reference_date)
    end_date = Date.add(start_date, 6)
    meals = list_meals_in_date_range(scope, start_date, end_date)
    meals_by_date = Enum.group_by(meals, &DateTime.to_date(&1.eaten_at))

    day_summaries =
      Enum.map(0..6, fn offset ->
        date = Date.add(start_date, offset)
        day_meals = Map.get(meals_by_date, date, [])
        totals = calculate_daily_totals(day_meals)

        %{
          date: date,
          short_label: Calendar.strftime(date, "%a"),
          total_calories: totals.total_calories,
          total_protein_g: totals.total_protein_g,
          total_carbs_g: totals.total_carbs_g,
          total_fats_g: totals.total_fats_g,
          meal_count: length(day_meals),
          meals: day_meals
        }
      end)

    totals =
      Enum.reduce(day_summaries, empty_totals(), fn day, acc ->
        %{
          total_calories: Decimal.add(acc.total_calories, day.total_calories),
          total_protein_g: Decimal.add(acc.total_protein_g, day.total_protein_g),
          total_carbs_g: Decimal.add(acc.total_carbs_g, day.total_carbs_g),
          total_fats_g: Decimal.add(acc.total_fats_g, day.total_fats_g)
        }
      end)

    %{
      start_date: start_date,
      end_date: end_date,
      day_summaries: day_summaries,
      totals: totals,
      average_calories: average_decimal(totals.total_calories, 7)
    }
  end

  @doc """
  Returns the most recent meal plan as a week planner.
  """
  def weekly_meal_plan(%Scope{user: user} = scope, reference_date \\ Date.utc_today()) do
    start_date = Date.beginning_of_week(reference_date)
    end_date = Date.add(start_date, 6)
    meals = list_meals_in_date_range(scope, start_date, end_date)
    meals_by_date = Enum.group_by(meals, &DateTime.to_date(&1.eaten_at))

    plan =
      MealPlan
      |> where([plan], plan.user_id == ^user.id)
      |> order_by([plan], desc: plan.updated_at)
      |> limit(1)
      |> Repo.one()
      |> Repo.preload(meal_plan_meals: [])

    days =
      Enum.map(0..6, fn offset ->
        date = Date.add(start_date, offset)
        day_of_week = rem(Date.day_of_week(date), 7)

        planned_meals =
          if plan,
            do: Enum.filter(plan.meal_plan_meals, &(&1.day_of_week == day_of_week)),
            else: []

        logged_meals = Map.get(meals_by_date, date, [])

        %{
          date: date,
          short_label: Calendar.strftime(date, "%a"),
          day_of_month: date.day,
          planned_meals: planned_meals,
          logged_meals: logged_meals,
          planned_totals: calculate_planned_totals(planned_meals),
          logged_totals: calculate_daily_totals(logged_meals)
        }
      end)

    %{plan: plan, start_date: start_date, end_date: end_date, days: days}
  end

  # Private helpers

  defp maybe_filter_by_date(query, nil), do: query

  defp maybe_filter_by_date(query, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    where(query, [meal], meal.eaten_at >= ^start_of_day and meal.eaten_at <= ^end_of_day)
  end

  defp maybe_filter_meals_by_search(query, search) when search in [nil, ""], do: query

  defp maybe_filter_meals_by_search(query, search) do
    like = "%#{String.trim(search)}%"
    where(query, [meal], ilike(meal.name, ^like) or ilike(meal.notes, ^like))
  end

  defp persist_meal(attrs, %Meal{} = meal) do
    normalized_items =
      normalize_meal_items(Map.get(attrs, "meal_items", Map.get(attrs, :meal_items, [])))

    totals = calculate_meal_totals(normalized_items)

    attrs =
      attrs
      |> Map.put("meal_items", normalized_items)
      |> Map.merge(%{
        "total_calories" => totals.total_calories,
        "total_protein_g" => totals.total_protein_g,
        "total_carbs_g" => totals.total_carbs_g,
        "total_fats_g" => totals.total_fats_g
      })

    Repo.transaction(fn ->
      changeset =
        meal
        |> Meal.changeset(Map.delete(attrs, "meal_items"))

      meal =
        case persist_meal_record(changeset, meal) do
          {:ok, meal} -> meal
          {:error, changeset} -> Repo.rollback(changeset)
        end

      from(item in MealItem, where: item.meal_id == ^meal.id) |> Repo.delete_all()

      Enum.each(normalized_items, fn item_attrs ->
        %MealItem{}
        |> MealItem.changeset(Map.put(item_attrs, "meal_id", meal.id))
        |> Repo.insert!()
      end)

      Repo.preload(meal, :meal_items)
    end)
    |> case do
      {:ok, meal} -> {:ok, meal}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  defp persist_meal_record(changeset, %Meal{id: nil}), do: Repo.insert(changeset)
  defp persist_meal_record(changeset, %Meal{}), do: Repo.update(changeset)

  defp normalize_meal_items(items) when is_list(items) do
    Enum.map(items, &normalize_meal_item/1)
  end

  defp normalize_meal_items(_), do: []

  defp normalize_meal_item(item) do
    %{
      "food_id" => item[:food_id] || item["food_id"],
      "food_name" =>
        item[:food_name] || item["food_name"] || item[:meal_name] || item["meal_name"],
      "quantity" => to_decimal(item[:quantity] || item["quantity"]),
      "unit" => item[:unit] || item["unit"] || "serving",
      "calories" => to_decimal(item[:calories] || item["calories"]),
      "protein_g" => to_decimal(item[:protein_g] || item["protein_g"]),
      "carbs_g" => to_decimal(item[:carbs_g] || item["carbs_g"]),
      "fats_g" => to_decimal(item[:fats_g] || item["fats_g"]),
      "fiber_g" => to_decimal(item[:fiber_g] || item["fiber_g"]),
      "sugar_g" => to_decimal(item[:sugar_g] || item["sugar_g"]),
      "sodium_mg" => to_decimal(item[:sodium_mg] || item["sodium_mg"]),
      "micronutrients" => parse_micronutrients(item[:micronutrients] || item["micronutrients"])
    }
  end

  defp normalize_stat_map(nil),
    do: %{
      total_calories: Decimal.new(0),
      total_protein_g: Decimal.new(0),
      total_carbs_g: Decimal.new(0),
      total_fats_g: Decimal.new(0)
    }

  defp normalize_stat_map(result) do
    %{
      total_calories: to_decimal(result.total_calories),
      total_protein_g: to_decimal(result.total_protein_g),
      total_carbs_g: to_decimal(result.total_carbs_g),
      total_fats_g: to_decimal(result.total_fats_g)
    }
  end

  defp fill_nutrition_dates(results, start_date, end_date) do
    result_map =
      Map.new(results, fn row ->
        {row.date,
         %{
           date: row.date,
           calories: to_decimal(row.calories),
           protein: to_decimal(row.protein),
           carbs: to_decimal(row.carbs),
           fats: to_decimal(row.fats)
         }}
      end)

    Date.range(start_date, end_date)
    |> Enum.map(fn date ->
      Map.get(result_map, date, %{
        date: date,
        calories: Decimal.new(0),
        protein: Decimal.new(0),
        carbs: Decimal.new(0),
        fats: Decimal.new(0)
      })
    end)
  end

  defp calculate_daily_totals(meals) do
    Enum.reduce(meals, empty_totals(), fn meal, acc ->
      %{
        total_calories: Decimal.add(acc.total_calories, to_decimal(meal.total_calories)),
        total_protein_g: Decimal.add(acc.total_protein_g, to_decimal(meal.total_protein_g)),
        total_carbs_g: Decimal.add(acc.total_carbs_g, to_decimal(meal.total_carbs_g)),
        total_fats_g: Decimal.add(acc.total_fats_g, to_decimal(meal.total_fats_g))
      }
    end)
  end

  defp calculate_planned_totals(plan_meals) do
    Enum.reduce(plan_meals, empty_totals(), fn meal, acc ->
      servings = to_decimal(meal.serving_count)

      %{
        total_calories:
          Decimal.add(
            acc.total_calories,
            Decimal.mult(to_decimal(meal.calories_per_serving), servings)
          ),
        total_protein_g:
          Decimal.add(
            acc.total_protein_g,
            Decimal.mult(to_decimal(meal.protein_g_per_serving), servings)
          ),
        total_carbs_g:
          Decimal.add(
            acc.total_carbs_g,
            Decimal.mult(to_decimal(meal.carbs_g_per_serving), servings)
          ),
        total_fats_g:
          Decimal.add(
            acc.total_fats_g,
            Decimal.mult(to_decimal(meal.fats_g_per_serving), servings)
          )
      }
    end)
  end

  defp empty_totals do
    %{
      total_calories: Decimal.new(0),
      total_protein_g: Decimal.new(0),
      total_carbs_g: Decimal.new(0),
      total_fats_g: Decimal.new(0)
    }
  end

  defp average_decimal(value, count) do
    value
    |> Decimal.div(Decimal.new(count))
    |> Decimal.round(2)
  end

  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
end
