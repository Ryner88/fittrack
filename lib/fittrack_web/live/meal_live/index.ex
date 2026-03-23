defmodule FittrackWeb.MealLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Meals</h1>
            <p class="text-sm text-base-content/70">
              Track your meals and monitor your nutritional intake over time.
            </p>
          </div>
          <div class="flex gap-3">
            <.link
              navigate={~p"/nutrition"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-chart-bar" class="mr-2 size-4" /> Dashboard
            </.link>
            <.link
              navigate={~p"/meals/new"}
              class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="mr-2 size-4" /> Log Meal
            </.link>
          </div>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm">
          <.form for={@form} id="meal-search-form" phx-change="search" phx-debounce="300">
            <div class="grid gap-4 md:grid-cols-[1fr_auto] md:items-end">
              <.input
                field={@form[:search]}
                type="search"
                label="Search meals"
                placeholder="Search by meal name"
              />
              <.link
                navigate={~p"/meals/new"}
                class="hidden md:inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              >
                Add new
              </.link>
            </div>
          </.form>
        </div>

        <.table
          id="meals"
          rows={@streams.meals}
          row_click={fn {_id, meal} -> JS.navigate(~p"/meals/#{meal}") end}
        >
          <:col :let={{_id, meal}} label="Name">{meal.name}</:col>
          <:col :let={{_id, meal}} label="Date & Time">
            {meal.eaten_at |> Calendar.strftime("%B %d, %Y at %I:%M %p")}
          </:col>
          <:col :let={{_id, meal}} label="Calories">{round(meal.total_calories || 0)}</:col>
          <:col :let={{_id, meal}} label="Protein">{round(meal.total_protein_g || 0)}g</:col>
          <:col :let={{_id, meal}} label="Carbs">{round(meal.total_carbs_g || 0)}g</:col>
          <:col :let={{_id, meal}} label="Fats">{round(meal.total_fats_g || 0)}g</:col>
          <:action :let={{_id, meal}}>
            <div class="sr-only">
              <.link navigate={~p"/meals/#{meal}"}>Show</.link>
            </div>
            <.link navigate={~p"/meals/#{meal}/edit"} class="text-primary hover:underline">
              Edit
            </.link>
          </:action>
          <:action :let={{id, meal}}>
            <.link
              phx-click={JS.push("delete", value: %{id: meal.id}) |> hide("##{id}")}
              data-confirm="Are you sure?"
              class="text-rose-500 hover:underline"
            >
              Delete
            </.link>
          </:action>
        </.table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Meals")
     |> assign(:form, to_form(%{"search" => ""}, as: :filters))
     |> stream(:meals, list_meals(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("search", %{"filters" => %{"search" => search}}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(%{"search" => search}, as: :filters))
     |> stream(:meals, list_meals(socket.assigns.current_scope), reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    meal = Nutrition.get_meal!(socket.assigns.current_scope, id)
    {:ok, _} = Nutrition.delete_meal(socket.assigns.current_scope, meal)

    {:noreply, stream_delete(socket, :meals, meal)}
  end

  defp list_meals(current_scope) do
    Nutrition.list_meals(current_scope)
  end
end
