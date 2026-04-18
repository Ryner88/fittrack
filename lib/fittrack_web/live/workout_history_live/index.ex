defmodule FittrackWeb.WorkoutHistoryLive.Index do
  use FittrackWeb, :live_view

  alias Decimal
  alias Fittrack.Training

  @weekdays ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <section class="overflow-hidden rounded-[2rem] border border-base-200 bg-[linear-gradient(140deg,#eff6ff_0%,#f8fafc_45%,#fefce8_100%)] p-8 shadow-sm">
          <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p class="text-xs uppercase tracking-[0.24em] text-slate-500">Workout history</p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
                Calendar view of completed training sessions
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-700">
                Browse each month, select any training day, and inspect the completed sessions, set count, and total lifted volume.
              </p>
            </div>
            <div class="flex flex-wrap gap-3">
              <.link
                navigate={~p"/workouts"}
                class="inline-flex items-center justify-center rounded-full border border-slate-300 bg-white/85 px-4 py-2.5 text-sm font-semibold text-slate-800 transition hover:border-slate-950 hover:text-slate-950"
              >
                <.icon name="hero-list-bullet" class="mr-2 h-4 w-4" /> Session list
              </.link>
              <.link
                navigate={~p"/workouts/new"}
                class="inline-flex items-center justify-center rounded-full bg-slate-950 px-4 py-2.5 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-slate-800"
              >
                <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Start workout
              </.link>
            </div>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(22rem,0.85fr)]">
          <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <button
                type="button"
                phx-click="previous_month"
                class="inline-flex h-11 w-11 items-center justify-center rounded-full border border-base-300 text-base-content transition hover:border-primary hover:text-primary"
              >
                <.icon name="hero-chevron-left" class="h-5 w-5" />
              </button>

              <div class="text-center">
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Month</p>
                <h2 class="mt-2 text-2xl font-semibold text-base-content">
                  {Calendar.strftime(@current_month, "%B %Y")}
                </h2>
              </div>

              <button
                type="button"
                phx-click="next_month"
                class="inline-flex h-11 w-11 items-center justify-center rounded-full border border-base-300 text-base-content transition hover:border-primary hover:text-primary"
              >
                <.icon name="hero-chevron-right" class="h-5 w-5" />
              </button>
            </div>

            <div class="mt-6 grid grid-cols-7 gap-2">
              <div
                :for={day_name <- @weekdays}
                class="px-2 py-3 text-center text-xs font-semibold uppercase tracking-[0.18em] text-base-content/50"
              >
                {day_name}
              </div>
            </div>

            <div id="workout-history-calendar" class="mt-2 grid grid-cols-7 gap-2">
              <%= for day <- @calendar_days do %>
                <%= if is_nil(day.date) do %>
                  <div class="aspect-square rounded-2xl border border-transparent bg-transparent">
                  </div>
                <% else %>
                  <button
                    type="button"
                    phx-click="select_date"
                    phx-value-date={Date.to_iso8601(day.date)}
                    class={[
                      "aspect-square rounded-2xl border p-2 text-left transition",
                      day.has_workout &&
                        "border-primary/30 bg-primary/10 shadow-sm hover:border-primary hover:bg-primary/15",
                      !day.has_workout &&
                        "border-base-200 bg-base-50 hover:border-base-300 hover:bg-base-100",
                      day.is_today && "ring-2 ring-primary/25",
                      @selected_date == day.date && "border-slate-950 ring-2 ring-slate-950/20"
                    ]}
                  >
                    <div class="flex h-full flex-col justify-between">
                      <span class="text-sm font-semibold text-base-content">{day.day}</span>
                      <%= if day.has_workout do %>
                        <div>
                          <span class="inline-flex rounded-full bg-white/80 px-2 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-primary">
                            {day.workout_count} session{if day.workout_count == 1, do: "", else: "s"}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="space-y-6">
            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Monthly summary</p>
              <h2 class="mt-2 text-2xl font-semibold text-base-content">
                {Calendar.strftime(@current_month, "%B")}
              </h2>

              <div class="mt-5 grid gap-3 sm:grid-cols-3">
                <div class="rounded-2xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Completed workouts</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.total_workouts}
                  </p>
                </div>
                <div class="rounded-2xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Total volume</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.total_volume}
                  </p>
                </div>
                <div class="rounded-2xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Avg / week</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.avg_workouts_per_week}
                  </p>
                </div>
              </div>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Selected day</p>
                  <h2 class="mt-2 text-2xl font-semibold text-base-content">
                    <%= if @selected_date do %>
                      {Calendar.strftime(@selected_date, "%B %d, %Y")}
                    <% else %>
                      Pick a workout day
                    <% end %>
                  </h2>
                </div>
                <%= if @selected_date do %>
                  <span class="rounded-full border border-base-200 bg-base-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">
                    {length(@selected_date_workouts)} session{if length(@selected_date_workouts) == 1,
                      do: "",
                      else: "s"}
                  </span>
                <% end %>
              </div>

              <div class="mt-5 space-y-3">
                <%= if is_nil(@selected_date) do %>
                  <div class="rounded-2xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/70">
                    Select a date from the calendar to inspect the workout sessions.
                  </div>
                <% else %>
                  <%= if Enum.empty?(@selected_date_workouts) do %>
                    <div class="rounded-2xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/70">
                      No completed sessions on this date.
                    </div>
                  <% else %>
                    <.link
                      :for={workout <- @selected_date_workouts}
                      navigate={~p"/workouts/#{workout}"}
                      class="block rounded-2xl border border-base-200 bg-base-50 px-4 py-4 transition hover:border-primary/40 hover:bg-white"
                    >
                      <div class="flex items-start justify-between gap-4">
                        <div>
                          <p class="font-semibold text-base-content">
                            Session at {Calendar.strftime(workout.started_at, "%I:%M %p")}
                          </p>
                          <p class="mt-1 text-sm text-base-content/60">
                            {length(workout.workout_sets)} sets • {workout_exercise_count(workout)} exercises
                          </p>
                          <p
                            :if={workout.notes not in [nil, ""]}
                            class="mt-2 text-sm text-base-content/70"
                          >
                            {workout.notes}
                          </p>
                        </div>
                        <div class="text-right text-sm">
                          <p class="font-semibold text-base-content">
                            {format_workout_volume(workout)} lbs
                          </p>
                          <p class="mt-1 text-base-content/60">{format_workout_duration(workout)}</p>
                        </div>
                      </div>
                    </.link>
                  <% end %>
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
    current_month = Date.beginning_of_month(Date.utc_today())

    {:ok,
     socket
     |> assign(:page_title, "Workout History")
     |> assign(:weekdays, @weekdays)
     |> assign(:current_month, current_month)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> load_month(socket.assigns.current_scope, current_month)}
  end

  @impl true
  def handle_event("previous_month", _params, socket) do
    current_month = shift_month(socket.assigns.current_month, -1)

    {:noreply,
     socket
     |> assign(:current_month, current_month)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> load_month(socket.assigns.current_scope, current_month)}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    current_month = shift_month(socket.assigns.current_month, 1)

    {:noreply,
     socket
     |> assign(:current_month, current_month)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> load_month(socket.assigns.current_scope, current_month)}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    selected_date = Date.from_iso8601!(date_string)

    {:noreply,
     socket
     |> assign(:selected_date, selected_date)
     |> assign(
       :selected_date_workouts,
       load_workouts_for_date(socket.assigns.current_scope, selected_date)
     )}
  end

  defp load_month(socket, scope, current_month) do
    socket
    |> assign(:calendar_days, calendar_days(scope, current_month))
    |> assign(:monthly_stats, monthly_stats(scope, current_month))
  end

  defp calendar_days(scope, current_month) do
    start_of_month = Date.beginning_of_month(current_month)
    end_of_month = Date.end_of_month(current_month)
    today = Date.utc_today()

    workout_counts =
      Training.workout_dates_in_month_with_counts(scope, start_of_month, end_of_month)
      |> Map.new(fn %{date: date, count: count} -> {date, count} end)

    padding = Date.day_of_week(start_of_month) - 1
    days = Date.days_in_month(current_month)

    leading =
      for _ <- 1..padding do
        %{date: nil, day: nil, has_workout: false, is_today: false, workout_count: 0}
      end

    current =
      for day <- 1..days do
        date = Date.new!(current_month.year, current_month.month, day)
        workout_count = Map.get(workout_counts, date, 0)

        %{
          date: date,
          day: day,
          has_workout: workout_count > 0,
          is_today: date == today,
          workout_count: workout_count
        }
      end

    trailing_count = rem(7 - rem(length(leading) + length(current), 7), 7)

    trailing =
      for _ <- 1..trailing_count do
        %{date: nil, day: nil, has_workout: false, is_today: false, workout_count: 0}
      end

    leading ++ current ++ trailing
  end

  defp monthly_stats(scope, current_month) do
    start_of_month = Date.beginning_of_month(current_month)
    end_of_month = Date.end_of_month(current_month)
    workouts = Training.list_workouts_in_date_range(scope, start_of_month, end_of_month)

    total_workouts = length(workouts)

    total_volume =
      Enum.reduce(workouts, Decimal.new(0), &Decimal.add(&2, workout_volume_decimal(&1)))

    weeks_in_month =
      current_month
      |> Date.days_in_month()
      |> Kernel./(7)

    %{
      total_workouts: total_workouts,
      total_volume: decimal_text(total_volume),
      avg_workouts_per_week: Float.round(total_workouts / max(weeks_in_month, 1), 1)
    }
  end

  defp load_workouts_for_date(scope, date) do
    Training.list_workouts_in_date_range(scope, date, date)
  end

  defp shift_month(date, amount) do
    month_index = date.month - 1 + amount
    year = date.year + div(month_index, 12)
    month = rem(month_index, 12)
    month = if month < 0, do: month + 12, else: month
    Date.new!(year, month + 1, 1)
  end

  defp workout_exercise_count(workout) do
    workout.workout_sets
    |> Enum.map(& &1.exercise_id)
    |> Enum.uniq()
    |> length()
  end

  defp format_workout_duration(workout) do
    case Enum.map(workout.workout_sets, & &1.inserted_at) do
      [] ->
        "0m"

      [single] ->
        if single, do: "0m", else: "0m"

      timestamps ->
        "#{max(DateTime.diff(Enum.max(timestamps), Enum.min(timestamps), :minute), 0)}m"
    end
  end

  defp format_workout_volume(workout) do
    workout
    |> workout_volume_decimal()
    |> decimal_text()
  end

  defp workout_volume_decimal(workout) do
    Enum.reduce(workout.workout_sets, Decimal.new(0), fn set, acc ->
      Decimal.add(acc, Decimal.mult(set.weight || Decimal.new(0), Decimal.new(set.reps || 0)))
    end)
  end

  defp decimal_text(%Decimal{} = value) do
    value
    |> Decimal.round(1)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end
end
