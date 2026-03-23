defmodule FittrackWeb.MealPlanLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.MealPlan

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>
          {@live_action == :new && "Create your meal plan."}
          {@live_action == :edit && "Edit your plan details."}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/meal-plans"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" /> Back
          </.link>
        </:actions>
      </.header>

      <.form for={@form} id="meal-plan-form" phx-change="validate" phx-submit="save">
        <div class="grid gap-4 md:grid-cols-2">
          <.input field={@form[:name]} type="text" label="Plan Name" required />
          <.input
            field={@form[:goal]}
            type="select"
            label="Goal"
            options={[{"Maintain", "maintain"}, {"Bulk", "bulk"}, {"Cut", "cut"}]}
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            class="md:col-span-2"
            rows="3"
          />

          <.input field={@form[:daily_calories_target]} type="number" label="Daily Calories" min="0" />
          <.input
            field={@form[:daily_protein_g_target]}
            type="number"
            label="Daily Protein (g)"
            min="0"
          />
          <.input field={@form[:daily_carbs_g_target]} type="number" label="Daily Carbs (g)" min="0" />
          <.input field={@form[:daily_fats_g_target]} type="number" label="Daily Fats (g)" min="0" />
        </div>

        <div class="mt-8 rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm">
          <div class="grid gap-4 md:grid-cols-2">
            <div>
              <h3 class="text-lg font-semibold mb-3">Food Library (Drag to a day)</h3>
              <div id="food-library" class="space-y-2 max-h-64 overflow-y-auto">
                <%= for food <- @food_library do %>
                  <div
                    id={"food-#{food.id}"}
                    class="draggable-item rounded-lg border border-base-300 bg-white p-2 text-sm cursor-grab"
                    draggable="true"
                    data-item-id={food.id}
                    data-item-type="food"
                    phx-hook="WorkoutPlanDragDrop"
                  >
                    <p class="font-medium">{food.name}</p>
                    <p class="text-xs text-base-content/60">
                      {Decimal.to_string(food.unit_amount)}{food.unit} / {Decimal.to_string(
                        food.calories_per_unit
                      )} cal
                    </p>
                  </div>
                <% end %>
              </div>
            </div>

            <div>
              <h3 class="text-lg font-semibold mb-3">Weekly Plan</h3>
              <div class="grid grid-cols-7 gap-2">
                <%= for {day, idx} <- Enum.with_index(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]) do %>
                  <div
                    id={"dropzone-#{day}"}
                    class="rounded-lg border border-base-300 p-2"
                    phx-hook="DropZone"
                    data-day={idx}
                  >
                    <p class="text-xs font-semibold text-base-content/70 mb-1">
                      {String.slice(day, 0, 3)}
                    </p>
                    <div class="h-24 overflow-y-auto text-xs space-y-1">
                      <%= for {meal, pos} <- Enum.with_index(Enum.filter(@meal_plan_meals, &(&1.day_of_week == idx))) do %>
                        <div class="flex items-center justify-between rounded-lg bg-base-50 px-2 py-1">
                          <span class="truncate text-xs">
                            {meal.meal_name} x{format_serving(meal.serving_count)}
                          </span>
                          <button
                            type="button"
                            phx-click="remove_plan_meal"
                            phx-value-id={Map.get(meal, :id) || "new"}
                            class="text-rose-500 hover:text-rose-700"
                          >
                            ✕
                          </button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-6 flex justify-end gap-2">
          <.button navigate={return_path(@return_to, @meal_plan)} class="btn btn-ghost">
            Cancel
          </.button>
          <.button phx-disable-with="Saving..." class="btn btn-primary">
            {@live_action == :new && "Create Plan"}
            {@live_action == :edit && "Update Plan"}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :new, _params) do
    meal_plan = %MealPlan{}
    changeset = Nutrition.change_meal_plan(meal_plan)

    socket
    |> assign(:page_title, "New Meal Plan")
    |> assign(:meal_plan, meal_plan)
    |> assign(:meal_plan_meals, [])
    |> assign(:food_library, Nutrition.list_foods(socket.assigns.current_scope))
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    meal_plan = Nutrition.get_meal_plan!(socket.assigns.current_scope, id)

    # Enrich meal_plan_meals with index for proper deletion
    enriched_meals = meal_plan.meal_plan_meals

    socket
    |> assign(:page_title, "Edit Meal Plan")
    |> assign(:meal_plan, meal_plan)
    |> assign(:meal_plan_meals, enriched_meals)
    |> assign(:food_library, Nutrition.list_foods(socket.assigns.current_scope))
    |> assign(:form, to_form(Nutrition.change_meal_plan(meal_plan)))
  end

  @impl true
  def handle_event("validate", %{"meal_plan" => meal_plan_params}, socket) do
    changeset =
      socket.assigns.meal_plan
      |> Nutrition.change_meal_plan(meal_plan_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event(
        "add_item_to_day",
        %{"item_id" => item_id, "item_type" => "food", "day" => day_num},
        socket
      ) do
    with {day_index, ""} <- Integer.parse(day_num),
         true <- day_index in 0..6,
         %Fittrack.Nutrition.Food{} = food <-
           Nutrition.get_food(socket.assigns.current_scope, item_id) do
      next_item = %{
        day_of_week: day_index,
        meal_name: food.name,
        serving_count: Decimal.new("1"),
        calories_per_serving: food.calories_per_unit || Decimal.new("0"),
        protein_g_per_serving: food.protein_per_unit || Decimal.new("0"),
        carbs_g_per_serving: food.carbs_per_unit || Decimal.new("0"),
        fats_g_per_serving: food.fats_per_unit || Decimal.new("0")
      }

      {:noreply, assign(socket, :meal_plan_meals, socket.assigns.meal_plan_meals ++ [next_item])}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_plan_meal", %{"id" => meal_id}, socket) do
    # Filter out the meal based on id (for existing meals) or filter by position (for newly added meals)
    meal_plan_meals =
      if meal_id == "new" do
        # Remove the last "new" meal if clicked on a new one
        Enum.drop(socket.assigns.meal_plan_meals, -1)
      else
        # Try to convert to integer for old-style index, fallback to id matching
        case Integer.parse(meal_id) do
          {idx, ""} ->
            List.delete_at(socket.assigns.meal_plan_meals, idx)

          :error ->
            # Remove by matching id on the struct
            Enum.reject(socket.assigns.meal_plan_meals, &(Map.get(&1, :id) == meal_id))
        end
      end

    {:noreply, assign(socket, :meal_plan_meals, meal_plan_meals)}
  end

  @impl true
  def handle_event("save", %{"meal_plan" => meal_plan_params}, socket) do
    meal_plan_params =
      Map.put(
        meal_plan_params,
        "meal_plan_meals",
        serialize_plan_meals(socket.assigns.meal_plan_meals)
      )

    case socket.assigns.live_action do
      :new ->
        case Nutrition.create_meal_plan(socket.assigns.current_scope, meal_plan_params) do
          {:ok, meal_plan} ->
            {:noreply,
             socket
             |> put_flash(:info, "Meal plan created successfully")
             |> push_navigate(to: return_path(socket.assigns.return_to, meal_plan))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      :edit ->
        case Nutrition.update_meal_plan(
               socket.assigns.current_scope,
               socket.assigns.meal_plan,
               meal_plan_params
             ) do
          {:ok, meal_plan} ->
            {:noreply,
             socket
             |> put_flash(:info, "Meal plan updated successfully")
             |> push_navigate(to: return_path(socket.assigns.return_to, meal_plan))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  defp serialize_plan_meals(meal_plan_meals) do
    Enum.map(meal_plan_meals, fn meal ->
      %{
        "day_of_week" => meal.day_of_week,
        "meal_name" => meal.meal_name,
        "serving_count" => serialize_decimal(meal.serving_count),
        "calories_per_serving" => serialize_decimal(meal.calories_per_serving),
        "protein_g_per_serving" => serialize_decimal(meal.protein_g_per_serving),
        "carbs_g_per_serving" => serialize_decimal(meal.carbs_g_per_serving),
        "fats_g_per_serving" => serialize_decimal(meal.fats_g_per_serving)
      }
    end)
  end

  defp serialize_decimal(nil), do: 0
  defp serialize_decimal(val) when is_struct(val, Decimal), do: Decimal.to_string(val)
  defp serialize_decimal(val) when is_float(val), do: val
  defp serialize_decimal(val) when is_integer(val), do: val
  defp serialize_decimal(val) when is_binary(val), do: val

  defp format_serving(nil), do: "1"
  defp format_serving(val) when is_struct(val, Decimal), do: round(Decimal.to_float(val))
  defp format_serving(val) when is_float(val), do: round(val)
  defp format_serving(val) when is_integer(val), do: val

  defp return_path("index", _meal_plan), do: ~p"/meal-plans"
  defp return_path("show", meal_plan), do: ~p"/meal-plans/#{meal_plan}"
end
