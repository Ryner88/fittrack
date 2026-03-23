defmodule FittrackWeb.FoodLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">My Foods</h1>
            <p class="text-sm text-base-content/70">
              Manage your personal food library for use in meals and meal plans.
            </p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={~p"/nutrition"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-arrow-left" class="mr-2 size-4" /> Dashboard
            </.link>
            <.link
              navigate={~p"/foods/new"}
              class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="mr-2 size-4" /> Add Food
            </.link>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <%= for food <- @foods do %>
            <.food_card food={food} />
          <% end %>
        </div>

        <%= if Enum.empty?(@foods) do %>
          <div class="text-center py-12">
            <div class="text-base-content/50">
              <.icon name="hero-squares-2x2" class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-base-content">No foods yet</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Create your first food to get started.
              </p>
              <div class="mt-6">
                <.link
                  navigate={~p"/foods/new"}
                  class="inline-flex items-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> Add your first food
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
     |> assign(:page_title, "My Foods")
     |> assign(:foods, list_foods(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    food = Nutrition.get_food!(socket.assigns.current_scope, id)
    {:ok, _} = Nutrition.delete_food(socket.assigns.current_scope, food)

    {:noreply,
     socket
     |> assign(:foods, list_foods(socket.assigns.current_scope))
     |> put_flash(:info, "Food deleted successfully")}
  end

  defp list_foods(current_scope) do
    Nutrition.list_foods(current_scope)
  end

  attr :food, :map, required: true

  defp food_card(assigns) do
    ~H"""
    <div class="group relative rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm transition hover:shadow-md hover:border-primary/20">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h3 class="font-semibold text-base-content group-hover:text-primary transition">
            {@food.name}
          </h3>
          <p class="text-sm text-base-content/70 mt-2">
            Per {Decimal.to_string(@food.unit_amount)}{@food.unit}
          </p>
          <div class="mt-3 space-y-1 text-xs text-base-content/60">
            <div class="flex justify-between">
              <span>Calories:</span>
              <span class="font-semibold">{Decimal.to_string(@food.calories_per_unit)} kcal</span>
            </div>
            <div class="flex justify-between">
              <span>Protein:</span>
              <span class="font-semibold">{Decimal.to_string(@food.protein_per_unit || 0)}g</span>
            </div>
            <div class="flex justify-between">
              <span>Carbs:</span>
              <span class="font-semibold">{Decimal.to_string(@food.carbs_per_unit || 0)}g</span>
            </div>
            <div class="flex justify-between">
              <span>Fats:</span>
              <span class="font-semibold">{Decimal.to_string(@food.fats_per_unit || 0)}g</span>
            </div>
          </div>
        </div>
        <div class="flex gap-2 opacity-0 transition group-hover:opacity-100">
          <.link
            navigate={~p"/foods/#{@food.id}/edit"}
            class="btn btn-sm btn-ghost"
            title="Edit"
          >
            <.icon name="hero-pencil" class="h-4 w-4" />
          </.link>
          <button
            type="button"
            phx-click="delete"
            phx-value-id={@food.id}
            data-confirm="Are you sure?"
            class="btn btn-sm btn-ghost text-error hover:text-error"
            title="Delete"
          >
            <.icon name="hero-trash" class="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end
end
