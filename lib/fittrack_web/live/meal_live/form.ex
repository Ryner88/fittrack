defmodule FittrackWeb.MealLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.Meal

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to log your meals and track nutritional intake.</:subtitle>
      </.header>

      <div class="space-y-6">
        <div class="grid gap-4 md:grid-cols-2">
          <.form for={@form} id="meal-form" phx-change="validate" phx-submit="save" class="contents">
            <.input field={@form[:name]} type="text" label="Meal Name" required />
            <.input field={@form[:eaten_at]} type="datetime-local" label="Date & Time" required />

            <.input
              field={@form[:notes]}
              type="textarea"
              label="Notes (optional)"
              class="md:col-span-2"
            />

            <div class="md:col-span-2 mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
              <div class="rounded-lg border border-base-200 p-3 text-center">
                <p class="text-sm text-base-content/70">Total Calories</p>
                <p class="text-2xl font-bold text-base-content">
                  {Decimal.to_string(@total_calories || Decimal.new(0))}
                </p>
              </div>
              <div class="rounded-lg border border-base-200 p-3 text-center">
                <p class="text-sm text-base-content/70">Protein</p>
                <p class="text-2xl font-bold text-base-content">
                  {Decimal.to_string(@total_protein_g || Decimal.new(0))}g
                </p>
              </div>
              <div class="rounded-lg border border-base-200 p-3 text-center">
                <p class="text-sm text-base-content/70">Carbs</p>
                <p class="text-2xl font-bold text-base-content">
                  {Decimal.to_string(@total_carbs_g || Decimal.new(0))}g
                </p>
              </div>
              <div class="rounded-lg border border-base-200 p-3 text-center">
                <p class="text-sm text-base-content/70">Fats</p>
                <p class="text-2xl font-bold text-base-content">
                  {Decimal.to_string(@total_fats_g || Decimal.new(0))}g
                </p>
              </div>
            </div>

            <footer class="mt-6 flex gap-2 md:col-span-2">
              <.button phx-disable-with="Saving..." variant="primary">Save Meal</.button>
              <.button navigate={return_path(@return_to, @meal)}>Cancel</.button>
            </footer>
          </.form>
        </div>

        <.form for={@food_library_form} id="food-library-form" phx-submit="add_food_item">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-4">
            <h3 class="text-lg font-semibold mb-3">Add from Food Library</h3>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-2 items-end">
              <div>
                <.input
                  field={@food_library_form[:food_id]}
                  type="select"
                  label="Food"
                  options={food_options(@foods)}
                  prompt="Select food"
                  required
                />
              </div>
              <div>
                <.input
                  field={@food_library_form[:quantity]}
                  type="number"
                  label="Quantity"
                  min="0.1"
                  step="0.1"
                  required
                />
              </div>
              <div>
                <.input field={@food_library_form[:unit]} type="text" label="Unit" required />
              </div>
              <button type="submit" class="btn btn-primary w-full">Add Item</button>
            </div>
          </div>
        </.form>

        <div class="mt-6">
          <h3 class="text-lg font-semibold">Meal Items</h3>
          <%= if Enum.empty?(@meal_items) do %>
            <p class="p-4 text-base-content/70">No items added yet.</p>
          <% else %>
            <div class="space-y-2">
              <%= for {item, id} <- Enum.with_index(@meal_items) do %>
                <div class="grid grid-cols-12 gap-2 p-3 rounded-lg border border-base-200 bg-base-50">
                  <div class="col-span-12 md:col-span-3">
                    <p class="font-semibold">{item.food_name}</p>
                    <p class="text-xs text-base-content/60">{item.quantity} {item.unit}</p>
                  </div>
                  <div class="col-span-12 md:col-span-7 text-sm text-base-content/80 grid grid-cols-4 gap-2">
                    <span>Cal {item.calories}</span>
                    <span>P {item.protein_g}g</span>
                    <span>C {item.carbs_g}g</span>
                    <span>F {item.fats_g}g</span>
                  </div>
                  <div class="col-span-12 md:col-span-2 flex justify-end">
                    <button
                      type="button"
                      phx-click="remove_item"
                      phx-value-id={id}
                      class="btn btn-ghost btn-sm text-rose-500"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:return_to, "index")
     |> assign(:foods, Nutrition.list_foods(current_scope))
     |> assign(:food_library_form, food_library_form())
     |> assign(:meal_items, [])
     |> assign(:new_item_quantity, 100)
     |> assign(:new_item_unit, "g")
     |> assign(:selected_food_id, nil)
     |> assign(:total_calories, Decimal.new(0))
     |> assign(:total_protein_g, Decimal.new(0))
     |> assign(:total_carbs_g, Decimal.new(0))
     |> assign(:total_fats_g, Decimal.new(0))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    meal = Nutrition.get_meal!(socket.assigns.current_scope, id)

    meal_items =
      Enum.map(meal.meal_items, fn item ->
        %{
          id: item.id,
          food_name: item.food_name,
          quantity: item.quantity,
          unit: item.unit,
          calories: item.calories,
          protein_g: item.protein_g,
          carbs_g: item.carbs_g,
          fats_g: item.fats_g,
          food_id: item.food_id
        }
      end)

    totals = Nutrition.calculate_meal_totals(meal_items)

    socket
    |> assign(:page_title, "Edit Meal")
    |> assign(:meal, meal)
    |> assign(:form, to_form(Nutrition.change_meal(meal)))
    |> assign(:food_library_form, food_library_form())
    |> assign(:meal_items, meal_items)
    |> assign(:selected_food_id, nil)
    |> assign(:total_calories, totals.total_calories)
    |> assign(:total_protein_g, totals.total_protein_g)
    |> assign(:total_carbs_g, totals.total_carbs_g)
    |> assign(:total_fats_g, totals.total_fats_g)
  end

  defp apply_action(socket, :new, _params) do
    meal = %Meal{eaten_at: DateTime.utc_now()}

    socket
    |> assign(:page_title, "Log Meal")
    |> assign(:meal, meal)
    |> assign(:form, to_form(Nutrition.change_meal(meal)))
    |> assign(:food_library_form, food_library_form())
    |> assign(:meal_items, [])
    |> assign(:selected_food_id, nil)
    |> assign(:total_calories, Decimal.new(0))
    |> assign(:total_protein_g, Decimal.new(0))
    |> assign(:total_carbs_g, Decimal.new(0))
    |> assign(:total_fats_g, Decimal.new(0))
  end

  @impl true
  def handle_event("validate", %{"meal" => meal_params}, socket) do
    changeset = Nutrition.change_meal(socket.assigns.meal, meal_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("select_food", %{"food-select" => food_id}, socket) do
    {:noreply, assign(socket, selected_food_id: food_id)}
  end

  def handle_event("add_food_item", %{"food_library" => food_library_params}, socket) do
    %{"food_id" => food_id, "quantity" => quantity, "unit" => unit} = food_library_params

    with %Fittrack.Nutrition.Food{} = food <-
           Nutrition.get_food(socket.assigns.current_scope, food_id),
         {qty, _} <- Float.parse(to_string(quantity)) do
      item =
        Nutrition.build_meal_item_from_food(socket.assigns.current_scope, to_string(food_id), qty)

      if item do
        item = Map.put(item, :unit, unit || food.unit)
        meal_items = socket.assigns.meal_items ++ [item]
        totals = Nutrition.calculate_meal_totals(meal_items)

        {:noreply,
         socket
         |> assign(:food_library_form, food_library_form(%{"unit" => unit}))
         |> assign(:meal_items, meal_items)
         |> assign(:total_calories, totals.total_calories)
         |> assign(:total_protein_g, totals.total_protein_g)
         |> assign(:total_carbs_g, totals.total_carbs_g)
         |> assign(:total_fats_g, totals.total_fats_g)}
      else
        {:noreply,
         assign(socket, :food_library_form, to_form(food_library_params, as: :food_library))}
      end
    else
      _ ->
        {:noreply,
         assign(socket, :food_library_form, to_form(food_library_params, as: :food_library))}
    end
  end

  def handle_event("remove_item", %{"id" => index}, socket) do
    index = String.to_integer(index)
    meal_items = List.delete_at(socket.assigns.meal_items, index)
    totals = Nutrition.calculate_meal_totals(meal_items)

    {:noreply,
     socket
     |> assign(:meal_items, meal_items)
     |> assign(:total_calories, totals.total_calories)
     |> assign(:total_protein_g, totals.total_protein_g)
     |> assign(:total_carbs_g, totals.total_carbs_g)
     |> assign(:total_fats_g, totals.total_fats_g)}
  end

  def handle_event("save", %{"meal" => meal_params}, socket) do
    meal_attrs =
      Map.merge(meal_params, %{
        "meal_items" => socket.assigns.meal_items
      })

    save_meal(socket, socket.assigns.live_action, meal_attrs)
  end

  defp save_meal(socket, :edit, meal_params) do
    case Nutrition.update_meal(
           socket.assigns.current_scope,
           socket.assigns.meal,
           meal_params
         ) do
      {:ok, meal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meal updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :update))}
    end
  end

  defp save_meal(socket, :new, meal_params) do
    case Nutrition.create_meal(socket.assigns.current_scope, meal_params) do
      {:ok, meal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meal created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  defp return_path("index", _meal), do: ~p"/meals"
  defp return_path("show", meal), do: ~p"/meals/#{meal}"

  defp food_library_form(attrs \\ %{}) do
    attrs
    |> Enum.into(%{"food_id" => nil, "quantity" => 100, "unit" => "g"})
    |> to_form(as: :food_library)
  end

  defp food_options(foods) do
    Enum.map(foods, fn food ->
      {"#{food.name} (#{food.unit_amount}#{food.unit})", food.id}
    end)
  end
end
