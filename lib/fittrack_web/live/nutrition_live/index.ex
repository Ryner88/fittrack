defmodule FittrackWeb.NutritionLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Nutrition Dashboard</h1>
            <p class="text-sm text-base-content/70">
              Track your meals and monitor your nutritional intake.
            </p>
          </div>
          <div class="flex gap-2">
            <.link navigate={~p"/meals/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="h-5 w-5" /> Log Meal
            </.link>
            <.link navigate={~p"/meal-plans"} class="btn btn-outline">
              <.icon name="hero-calendar-days" class="h-5 w-5" /> Meal Plans
            </.link>
            <.link navigate={~p"/foods"} class="btn btn-outline">
              <.icon name="hero-squares-2x2" class="h-5 w-5" /> My Foods
            </.link>
          </div>
        </div>
        
    <!-- Today's Nutrition Stats -->
        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-fire" class="h-8 w-8 text-orange-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Calories Today</p>
                <p class="text-2xl font-bold text-base-content">
                  {round(@today_stats.total_calories || 0)}
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-scale" class="h-8 w-8 text-blue-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Protein</p>
                <p class="text-2xl font-bold text-base-content">
                  {round(@today_stats.total_protein_g || 0)}g
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-cake" class="h-8 w-8 text-green-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Carbs</p>
                <p class="text-2xl font-bold text-base-content">
                  {round(@today_stats.total_carbs_g || 0)}g
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-droplet" class="h-8 w-8 text-purple-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Fats</p>
                <p class="text-2xl font-bold text-base-content">
                  {round(@today_stats.total_fats_g || 0)}g
                </p>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Charts Row -->
        <div class="grid gap-6 lg:grid-cols-2">
          <!-- Calorie Intake Chart -->
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">
              Calorie Intake (Last 30 Days)
            </h3>
            <div class="h-80">
              <canvas
                id="calorie-chart"
                phx-hook="CalorieChart"
                data-chart-data={Jason.encode!(@calorie_chart)}
              >
              </canvas>
            </div>
          </div>
          
    <!-- Macro Distribution Chart -->
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">Today's Macro Distribution</h3>
            <div class="h-80">
              <canvas
                id="macro-chart"
                phx-hook="MacroChart"
                data-chart-data={Jason.encode!(@macro_chart)}
              >
              </canvas>
            </div>
          </div>
        </div>
        
    <!-- Recent Meals -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-base-content">Recent Meals</h3>
            <.link navigate={~p"/meals"} class="text-sm text-primary hover:underline">
              View all →
            </.link>
          </div>

          <div class="space-y-3">
            <%= for meal <- @recent_meals do %>
              <div class="flex items-center justify-between p-3 rounded-lg bg-base-50">
                <div>
                  <p class="font-medium text-base-content">{meal.name}</p>
                  <p class="text-sm text-base-content/70">
                    {meal.eaten_at |> Calendar.strftime("%B %d, %Y at %I:%M %p")}
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold text-primary">{round(meal.total_calories || 0)} cal</p>
                  <p class="text-sm text-base-content/70">
                    {round(meal.total_protein_g || 0)}g P • {round(meal.total_carbs_g || 0)}g C • {round(
                      meal.total_fats_g || 0
                    )}g F
                  </p>
                </div>
              </div>
            <% end %>
          </div>

          <%= if Enum.empty?(@recent_meals) do %>
            <div class="text-center py-8">
              <p class="text-base-content/70 mb-4">No meals logged yet.</p>
              <.link navigate={~p"/meals/new"} class="btn btn-primary">
                Log Your First Meal
              </.link>
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
     |> assign(:page_title, "Nutrition Dashboard")
     |> assign(:today_stats, load_today_stats(current_scope))
     |> assign(:calorie_chart, load_calorie_chart(current_scope))
     |> assign(:macro_chart, load_macro_chart(current_scope))
     |> assign(:recent_meals, load_recent_meals(current_scope))}
  end

  defp load_today_stats(scope) do
    Nutrition.get_nutrition_stats(scope, Date.utc_today())
  end

  defp load_calorie_chart(scope) do
    nutrition_data = Nutrition.nutrition_over_time(scope, 30)

    %{
      labels: Enum.map(nutrition_data, &(&1.date |> Calendar.strftime("%m/%d"))),
      datasets: [
        %{
          label: "Calories",
          data: Enum.map(nutrition_data, & &1.calories),
          backgroundColor: "rgba(249, 115, 22, 0.5)",
          borderColor: "rgba(249, 115, 22, 1)",
          borderWidth: 1
        }
      ]
    }
  end

  defp load_macro_chart(scope) do
    stats = load_today_stats(scope)

    %{
      labels: ["Protein", "Carbs", "Fats"],
      datasets: [
        %{
          data: [stats.total_protein_g || 0, stats.total_carbs_g || 0, stats.total_fats_g || 0],
          backgroundColor: [
            "rgba(59, 130, 246, 0.8)",
            "rgba(34, 197, 94, 0.8)",
            "rgba(147, 51, 234, 0.8)"
          ],
          borderWidth: 1
        }
      ]
    }
  end

  defp load_recent_meals(scope) do
    Nutrition.list_meals(scope, %{limit: 5})
  end
end
