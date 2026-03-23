defmodule FittrackWeb.MealPlanLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Meal Plan: {@meal_plan.name}
        <:subtitle>
          {@meal_plan.goal} • {round(@meal_plan.daily_calories_target || 0)} cal/day
        </:subtitle>
        <:actions>
          <.button navigate={~p"/meal-plans"}>
            <.icon name="hero-arrow-left" /> Back
          </.button>
          <.button variant="primary" navigate={~p"/meal-plans/#{@meal_plan}/edit?return_to=show"}>
            <.icon name="hero-pencil" /> Edit
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@meal_plan.name}</:item>
        <:item title="Goal">{@meal_plan.goal}</:item>
        <:item title="Daily Calories">{round(@meal_plan.daily_calories_target || 0)} cal</:item>
        <:item title="Daily Protein">{round(@meal_plan.daily_protein_g_target || 0)}g</:item>
        <:item title="Daily Carbs">{round(@meal_plan.daily_carbs_g_target || 0)}g</:item>
        <:item title="Daily Fats">{round(@meal_plan.daily_fats_g_target || 0)}g</:item>
        <:item title="Description">{@meal_plan.description || "None"}</:item>
      </.list>

      <div class="mt-6">
        <h3 class="text-lg font-semibold mb-3">Scheduled Meals</h3>
        <%= if Enum.empty?(@meal_plan.meal_plan_meals) do %>
          <p class="text-base-content/70">No meals added to this plan yet.</p>
        <% else %>
          <div class="space-y-2">
            <%= for meal <- @meal_plan.meal_plan_meals do %>
              <div class="rounded-lg border border-base-200 p-3">
                <p class="font-medium">
                  {meal.meal_name} — {Enum.at(
                    ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                    meal.day_of_week
                  )}
                </p>
                <p class="text-sm text-base-content/70">
                  {round(meal.serving_count || 0)} serving(s), {round(meal.calories_per_serving || 0)} cal
                </p>
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
    meal_plan = Nutrition.get_meal_plan!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Meal Plan")
     |> assign(:meal_plan, meal_plan)}
  end
end
