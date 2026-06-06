defmodule FittrackWeb.NutritionLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="overflow-hidden rounded-2xl border border-base-200 bg-[linear-gradient(135deg,#fff7ed_0%,#fffbeb_38%,#f8fafc_100%)] p-8 shadow-sm">
          <div class="grid gap-8 lg:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.9fr)] lg:items-end">
            <div>
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">Nutrition module</p>
              <h1 class="mt-3 max-w-2xl text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
                Log meals, plan your week, and keep your intake aligned with training.
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-700">
                Your dashboard combines today’s intake, the active weekly meal plan, and recent logging activity in one place.
              </p>
              <div class="mt-6 flex flex-wrap gap-3">
                <.link
                  navigate={~p"/meals/new"}
                  class="inline-flex items-center justify-center rounded-full bg-slate-950 px-5 py-2.5 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-slate-800"
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Log meal
                </.link>
                <.link
                  navigate={~p"/meal-plans/new"}
                  class="inline-flex items-center justify-center rounded-full border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-semibold text-slate-800 transition hover:border-slate-950 hover:text-slate-950"
                >
                  <.icon name="hero-calendar-days" class="mr-2 h-4 w-4" /> Build weekly plan
                </.link>
                <.link
                  navigate={~p"/foods"}
                  class="inline-flex items-center justify-center rounded-full border border-slate-300 bg-white/80 px-5 py-2.5 text-sm font-semibold text-slate-800 transition hover:border-slate-950 hover:text-slate-950"
                >
                  <.icon name="hero-squares-2x2" class="mr-2 h-4 w-4" /> Food library
                </.link>
              </div>
            </div>

            <div class="rounded-2xl border border-white/70 bg-white/80 p-6 shadow-sm backdrop-blur">
              <p class="text-xs uppercase tracking-[0.2em] text-slate-500">Today</p>
              <div class="mt-4 grid grid-cols-2 gap-3">
                <div class="rounded-2xl bg-orange-50 p-4">
                  <p class="text-sm text-orange-700">Calories</p>
                  <p class="mt-1 text-2xl font-semibold text-orange-950">
                    {decimal_text(@today_stats.total_calories)}
                  </p>
                </div>
                <div class="rounded-2xl bg-sky-50 p-4">
                  <p class="text-sm text-sky-700">Protein</p>
                  <p class="mt-1 text-2xl font-semibold text-sky-950">
                    {decimal_text(@today_stats.total_protein_g)}g
                  </p>
                </div>
                <div class="rounded-2xl bg-emerald-50 p-4">
                  <p class="text-sm text-emerald-700">Carbs</p>
                  <p class="mt-1 text-2xl font-semibold text-emerald-950">
                    {decimal_text(@today_stats.total_carbs_g)}g
                  </p>
                </div>
                <div class="rounded-2xl bg-amber-50 p-4">
                  <p class="text-sm text-amber-700">Fats</p>
                  <p class="mt-1 text-2xl font-semibold text-amber-950">
                    {decimal_text(@today_stats.total_fats_g)}g
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(22rem,0.8fr)]">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Weekly planner</p>
                <h2 class="mt-2 text-2xl font-semibold text-base-content">
                  <%= if @weekly_plan.plan do %>
                    {@weekly_plan.plan.name}
                  <% else %>
                    No active meal plan
                  <% end %>
                </h2>
                <p class="mt-1 text-sm text-base-content/70">
                  {Calendar.strftime(@weekly_plan.start_date, "%b %d")} to {Calendar.strftime(
                    @weekly_plan.end_date,
                    "%b %d"
                  )}
                </p>
              </div>
              <.link
                navigate={~p"/meal-plans"}
                class="text-sm font-semibold text-primary transition hover:underline"
              >
                Manage plans
              </.link>
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-7">
              <%= for day <- @weekly_plan.days do %>
                <article class="relative flex min-h-64 flex-col overflow-hidden rounded-2xl border border-base-200 bg-base-50 p-4">
                  <%= if length(day.logged_meals) > 0 do %>
                    <span class="absolute top-3 right-3 w-auto max-w-[calc(100%-1.5rem)] truncate rounded-full border border-sky-200 bg-sky-50 px-2.5 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.14em] text-sky-800 shadow-sm">
                      {length(day.logged_meals)} logged
                    </span>
                  <% end %>

                  <div class="flex items-end gap-2 pr-[4.5rem] pt-2">
                    <div>
                      <p class="text-xs uppercase tracking-[0.18em] text-base-content/50">
                        {day.short_label}
                      </p>
                      <p class="mt-1 text-xl font-semibold text-base-content">{day.day_of_month}</p>
                    </div>
                  </div>

                  <div class="mt-4 space-y-2">
                    <%= if Enum.empty?(day.planned_meals) do %>
                      <p class="rounded-2xl border border-dashed border-base-300 px-3 py-3 text-xs text-base-content/60">
                        No planned meals
                      </p>
                    <% else %>
                      <div
                        :for={meal <- day.planned_meals}
                        class="rounded-2xl border border-base-200 bg-base-100 px-3 py-3 shadow-sm"
                      >
                        <p class="text-sm font-semibold text-base-content">{meal.meal_name}</p>
                        <p class="mt-1 text-xs text-base-content/60">
                          {decimal_text(meal.serving_count)} serving • {decimal_text(
                            meal.calories_per_serving
                          )} cal each
                        </p>
                      </div>
                    <% end %>
                  </div>

                  <div class="mt-auto pt-4 text-xs text-base-content/60">
                    <p>Planned: {decimal_text(day.planned_totals.total_calories)} cal</p>
                    <p>Logged: {decimal_text(day.logged_totals.total_calories)} cal</p>
                  </div>
                </article>
              <% end %>
            </div>
          </div>

          <div class="space-y-6">
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
              <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">This week</p>
              <h2 class="mt-2 text-2xl font-semibold text-base-content">Nutrition overview</h2>

              <div class="mt-5 grid gap-3 sm:grid-cols-2">
                <div class="rounded-2xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Weekly calories</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {decimal_text(@weekly_overview.totals.total_calories)}
                  </p>
                </div>
                <div class="rounded-2xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Average/day</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {decimal_text(@weekly_overview.average_calories)}
                  </p>
                </div>
              </div>

              <div class="mt-5 space-y-3">
                <div
                  :for={day <- @weekly_overview.day_summaries}
                  class="grid gap-3 rounded-2xl border border-base-200 bg-base-50 px-4 py-3 sm:grid-cols-[4rem_minmax(0,1fr)_auto]"
                >
                  <div>
                    <p class="text-xs uppercase tracking-[0.18em] text-base-content/50">
                      {day.short_label}
                    </p>
                    <p class="mt-1 text-lg font-semibold text-base-content">{day.date.day}</p>
                  </div>
                  <div class="grid gap-2 text-sm text-base-content/70 sm:grid-cols-4">
                    <p>
                      <span class="font-semibold text-base-content">Cal</span> {decimal_text(
                        day.total_calories
                      )}
                    </p>
                    <p>
                      <span class="font-semibold text-base-content">P</span> {decimal_text(
                        day.total_protein_g
                      )}g
                    </p>
                    <p>
                      <span class="font-semibold text-base-content">C</span> {decimal_text(
                        day.total_carbs_g
                      )}g
                    </p>
                    <p>
                      <span class="font-semibold text-base-content">F</span> {decimal_text(
                        day.total_fats_g
                      )}g
                    </p>
                  </div>
                  <p class="text-sm font-semibold text-base-content">{day.meal_count} meals</p>
                </div>
              </div>
            </div>

            <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Recent meals</p>
                  <h2 class="mt-2 text-2xl font-semibold text-base-content">Latest entries</h2>
                </div>
                <.link
                  navigate={~p"/meals"}
                  class="text-sm font-semibold text-primary transition hover:underline"
                >
                  View all
                </.link>
              </div>

              <div class="mt-5 space-y-3">
                <%= if Enum.empty?(@recent_meals) do %>
                  <div class="rounded-2xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/70">
                    No meals logged yet.
                  </div>
                <% else %>
                  <.link
                    :for={meal <- @recent_meals}
                    navigate={~p"/meals/#{meal}"}
                    class="block rounded-2xl border border-base-200 bg-base-50 px-4 py-4 transition hover:border-primary/40 hover:bg-white"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="font-semibold text-base-content">{meal.name}</p>
                        <p class="mt-1 text-sm text-base-content/60">
                          {Calendar.strftime(meal.eaten_at, "%b %d at %I:%M %p")}
                        </p>
                      </div>
                      <div class="text-right text-sm">
                        <p class="font-semibold text-base-content">
                          {decimal_text(meal.total_calories)} cal
                        </p>
                        <p class="mt-1 text-base-content/60">
                          {decimal_text(meal.total_protein_g)}P / {decimal_text(meal.total_carbs_g)}C / {decimal_text(
                            meal.total_fats_g
                          )}F
                        </p>
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </section>
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
     |> assign(:today_stats, Nutrition.get_nutrition_stats(current_scope, Date.utc_today()))
     |> assign(:weekly_overview, Nutrition.weekly_nutrition_overview(current_scope))
     |> assign(:weekly_plan, Nutrition.weekly_meal_plan(current_scope))
     |> assign(:recent_meals, Nutrition.list_meals(current_scope, %{limit: 5}))}
  end

  defp decimal_text(%Decimal{} = value) do
    value
    |> Decimal.round(1)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp decimal_text(nil), do: "0"
end
