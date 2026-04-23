defmodule FittrackWeb.MealLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Meal: {@meal.name}
        <:subtitle>Logged on {Calendar.strftime(@meal.eaten_at, "%B %d, %Y at %I:%M %p")}</:subtitle>
        <:actions>
          <.button navigate={~p"/meals"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/meals/#{@meal}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit meal
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@meal.name}</:item>
        <:item title="Date & Time">
          {Calendar.strftime(@meal.eaten_at, "%B %d, %Y at %I:%M %p")}
        </:item>
        <:item title="Total Calories">{display_number(@meal.total_calories)}</:item>
        <:item title="Total Protein">{display_number(@meal.total_protein_g)}g</:item>
        <:item title="Total Carbs">{display_number(@meal.total_carbs_g)}g</:item>
        <:item title="Total Fats">{display_number(@meal.total_fats_g)}g</:item>
        <:item title="Notes">{@meal.notes || "No notes"}</:item>
      </.list>
      
    <!-- Meal Items -->
      <div class="mt-6">
        <h3 class="text-lg font-semibold mb-4">Food Items</h3>

        <%= if Enum.empty?(@meal.meal_items) do %>
          <p class="text-base-content/70">No food items logged for this meal.</p>
        <% else %>
          <div class="space-y-3">
            <%= for item <- @meal.meal_items do %>
              <div class="p-4 border border-base-200 rounded-lg">
                <div class="flex justify-between items-start">
                  <div>
                    <h4 class="font-medium">{item.food_name}</h4>
                    <p class="text-sm text-base-content/70">
                      {item.quantity} {item.unit}
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="font-bold">{display_number(item.calories)} cal</p>
                    <p class="text-sm text-base-content/70">
                      {display_number(item.protein_g)}g P • {display_number(item.carbs_g)}g C • {display_number(
                        item.fats_g
                      )}g F
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Meal")
     |> assign(:meal, Nutrition.get_meal!(socket.assigns.current_scope, id))}
  end

  defp display_number(nil), do: 0
  defp display_number(%Decimal{} = value), do: value |> Decimal.to_float() |> round()
  defp display_number(value) when is_integer(value), do: value
  defp display_number(value) when is_float(value), do: round(value)
end
