defmodule FittrackWeb.MealPlanLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Meal Plans</h1>
            <p class="text-sm text-base-content/70">
              Create and manage meal plans for consistent nutrition tracking.
            </p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={~p"/nutrition"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-chart-bar" class="mr-2 size-4" /> Dashboard
            </.link>
            <.link
              navigate={~p"/meal-plans/new"}
              class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="mr-2 size-4" /> Create plan
            </.link>
          </div>
        </div>

        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          <%= for meal_plan <- @meal_plans do %>
            <.meal_plan_card meal_plan={meal_plan} />
          <% end %>
        </div>

        <%= if Enum.empty?(@meal_plans) do %>
          <div class="text-center py-12">
            <div class="text-base-content/50">
              <.icon name="hero-document-text" class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-base-content">No meal plans yet</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Create your first meal plan to get started.
              </p>
              <div class="mt-6">
                <.link
                  navigate={~p"/meal-plans/new"}
                  class="inline-flex items-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> Create your first plan
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meal Plans")
     |> assign(:meal_plans, list_meal_plans(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    meal_plan = Nutrition.get_meal_plan!(socket.assigns.current_scope, id)
    {:ok, _} = Nutrition.delete_meal_plan(socket.assigns.current_scope, meal_plan)

    {:noreply,
     socket
     |> assign(:meal_plans, list_meal_plans(socket.assigns.current_scope))
     |> put_flash(:info, "Meal plan deleted successfully")}
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    meal_plan = Nutrition.get_meal_plan!(socket.assigns.current_scope, id)

    # Create a duplicate with "Copy of" prefix
    attrs = %{
      name: "Copy of #{meal_plan.name}",
      description: meal_plan.description,
      goal: meal_plan.goal,
      daily_calories_target: meal_plan.daily_calories_target,
      daily_protein_g_target: meal_plan.daily_protein_g_target,
      daily_carbs_g_target: meal_plan.daily_carbs_g_target,
      daily_fats_g_target: meal_plan.daily_fats_g_target,
      meal_plan_meals:
        meal_plan.meal_plan_meals
        |> Enum.map(fn meal ->
          %{
            day_of_week: meal.day_of_week,
            meal_name: meal.meal_name,
            serving_count: meal.serving_count,
            calories_per_serving: meal.calories_per_serving,
            protein_g_per_serving: meal.protein_g_per_serving,
            carbs_g_per_serving: meal.carbs_g_per_serving,
            fats_g_per_serving: meal.fats_g_per_serving
          }
        end)
    }

    case Nutrition.create_meal_plan(socket.assigns.current_scope, attrs) do
      {:ok, _new_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meal plan duplicated successfully")
         |> assign(:meal_plans, list_meal_plans(socket.assigns.current_scope))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to duplicate meal plan")}
    end
  end

  defp list_meal_plans(current_scope) do
    Nutrition.list_meal_plans(current_scope)
  end

  attr :meal_plan, :map, required: true

  defp meal_plan_card(assigns) do
    ~H"""
    <div class="group relative rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm transition hover:shadow-md hover:border-primary/20">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h3 class="font-semibold text-base-content group-hover:text-primary transition">
            {@meal_plan.name}
          </h3>
          <%= if @meal_plan.description do %>
            <p class="text-sm text-base-content/70 mt-1 line-clamp-2">
              {@meal_plan.description}
            </p>
          <% end %>
          <div class="mt-3 flex items-center gap-4 text-sm text-base-content/60">
            <.icon name="hero-queue-list" class="h-4 w-4" />
            <span>{length(@meal_plan.meal_plan_meals)} meals</span>
            <.icon name="hero-fire" class="h-4 w-4 ml-2" />
            <span>{round(@meal_plan.daily_calories_target || 0)} cal/day</span>
          </div>
          <div class="mt-2 text-xs text-base-content/50 capitalize">
            Goal: {@meal_plan.goal}
          </div>
        </div>
      </div>

      <div class="mt-6 flex items-center justify-between">
        <div class="flex gap-2">
          <.link
            navigate={~p"/meal-plans/#{@meal_plan}"}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-eye" class="h-3 w-3" /> View
          </.link>
          <.link
            navigate={~p"/meal-plans/#{@meal_plan}/edit"}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-pencil" class="h-3 w-3" /> Edit
          </.link>
          <button
            phx-click="duplicate"
            phx-value-id={@meal_plan.id}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-document-duplicate" class="h-3 w-3" /> Duplicate
          </button>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="delete"
            phx-value-id={@meal_plan.id}
            data-confirm="Are you sure you want to delete this meal plan?"
            class="inline-flex items-center gap-2 rounded-lg border border-rose-300 px-3 py-1.5 text-xs font-medium text-rose-600 transition hover:bg-rose-50"
          >
            <.icon name="hero-trash" class="h-3 w-3" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end
end
