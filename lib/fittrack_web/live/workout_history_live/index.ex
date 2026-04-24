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
        <section class="border-b border-base-200 pb-6">
          <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <h1 class="text-3xl font-semibold tracking-tight text-base-content sm:text-4xl">
                Workout History
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-base-content/70">
                Review completed workouts, track performance, and monitor progress over time.
              </p>
            </div>

            <div class="flex flex-wrap gap-3">
              <%= if @active_workout do %>
                <.link
                  id="resume-workout-link"
                  navigate={~p"/workouts/#{@active_workout}"}
                  class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                >
                  <.icon name="hero-play" class="mr-2 h-4 w-4" /> Resume workout
                </.link>
              <% else %>
                <.link
                  id="start-workout-link"
                  navigate={~p"/workouts/new"}
                  class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Start workout
                </.link>
                <.link
                  id="browse-plans-link"
                  navigate={~p"/workout-plans"}
                  class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                >
                  <.icon name="hero-clipboard-document-list" class="mr-2 h-4 w-4" /> Browse plans
                </.link>
              <% end %>
            </div>
          </div>
        </section>

        <section
          id="history-summary-stats"
          class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
        >
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm">
            <p class="text-sm text-base-content/60">Workouts this week</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">
              {@summary_stats.workouts_this_week}
            </p>
          </div>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm">
            <p class="text-sm text-base-content/60">Average duration</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">
              {@summary_stats.average_duration}
            </p>
          </div>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm">
            <p class="text-sm text-base-content/60">Total volume</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">
              {@summary_stats.total_volume} lbs
            </p>
          </div>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm">
            <p class="text-sm text-base-content/60">Streak</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">
              {@summary_stats.streak_days} days
            </p>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1.1fr)_minmax(24rem,0.9fr)]">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <button
                id="history-previous-month"
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
                id="history-next-month"
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
                  <div class="aspect-square rounded-lg border border-transparent bg-transparent">
                  </div>
                <% else %>
                  <button
                    type="button"
                    phx-click="select_date"
                    phx-value-date={Date.to_iso8601(day.date)}
                    class={[
                      "aspect-square rounded-lg border p-2 text-left transition",
                      day.has_workout &&
                        "border-primary/30 bg-primary/10 shadow-sm hover:border-primary hover:bg-primary/15",
                      !day.has_workout &&
                        "border-base-200 bg-base-50 hover:border-base-300 hover:bg-base-100",
                      day.is_today && "ring-2 ring-primary/25",
                      @selected_date == day.date && "border-base-content ring-2 ring-base-content/20"
                    ]}
                  >
                    <div class="flex h-full flex-col justify-between">
                      <span class="text-sm font-semibold text-base-content">{day.day}</span>
                      <%= if day.has_workout do %>
                        <span class="w-fit rounded-full bg-white/90 px-2 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.16em] text-primary">
                          {day.workout_count} done
                        </span>
                      <% end %>
                    </div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>

          <div class="space-y-6">
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
              <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Monthly summary</p>
              <h2 class="mt-2 text-2xl font-semibold text-base-content">
                {Calendar.strftime(@current_month, "%B")}
              </h2>

              <div class="mt-5 grid gap-3 sm:grid-cols-3 xl:grid-cols-1">
                <div class="rounded-xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Completed workouts</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.total_workouts}
                  </p>
                </div>
                <div class="rounded-xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Total volume</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.total_volume} lbs
                  </p>
                </div>
                <div class="rounded-xl bg-base-50 p-4">
                  <p class="text-sm text-base-content/60">Avg / week</p>
                  <p class="mt-1 text-2xl font-semibold text-base-content">
                    {@monthly_stats.avg_workouts_per_week}
                  </p>
                </div>
              </div>
            </div>

            <div
              id="history-selected-day"
              class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm"
            >
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
                    {length(@selected_date_workouts)} completed
                  </span>
                <% end %>
              </div>

              <div class="mt-5 space-y-3">
                <%= cond do %>
                  <% is_nil(@selected_date) -> %>
                    <div class="rounded-2xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/70">
                      Select a date from the calendar to inspect completed workouts.
                    </div>
                  <% Enum.empty?(@selected_date_workouts) -> %>
                    <div class="rounded-2xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/70">
                      No completed workouts on this date.
                    </div>
                  <% true -> %>
                    <div
                      :for={workout <- @selected_date_workouts}
                      id={"history-workout-#{workout.id}"}
                      class="rounded-2xl border border-base-200 bg-base-50 px-4 py-4"
                    >
                      <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                        <div class="min-w-0">
                          <p class="font-semibold text-base-content">
                            {workout_name(workout)}
                          </p>
                          <p class="mt-1 text-sm text-base-content/60">
                            Plan: {linked_plan_name(workout)}
                          </p>
                          <p class="mt-2 text-sm text-base-content/70">
                            {Calendar.strftime(workout.started_at, "%b %d, %Y at %I:%M %p")} • {format_workout_duration(
                              workout
                            )}
                          </p>
                          <p class="mt-1 text-sm text-base-content/70">
                            {workout_exercise_count(workout)} exercises • {length(
                              workout.workout_sets
                            )} sets • {workout_reps(workout)} reps
                          </p>
                          <p
                            :if={workout.notes not in [nil, ""]}
                            class="mt-2 text-sm text-base-content/70"
                          >
                            {workout.notes}
                          </p>
                        </div>
                        <div class="flex shrink-0 flex-col items-start gap-3 sm:items-end">
                          <div class="text-left text-sm sm:text-right">
                            <p class="font-semibold text-base-content">
                              {format_workout_volume(workout)} lbs
                            </p>
                            <p class="mt-1 text-base-content/60">Total volume</p>
                          </div>
                          <.link
                            navigate={~p"/workouts/#{workout}"}
                            class="inline-flex items-center justify-center rounded-full border border-base-300 px-3 py-1.5 text-xs font-semibold text-base-content transition hover:border-primary hover:text-primary"
                          >
                            View details
                          </.link>
                        </div>
                      </div>
                    </div>
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
     |> assign(:active_workout, Training.get_active_workout(socket.assigns.current_scope))
     |> assign(:summary_stats, summary_stats(socket.assigns.current_scope))
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
      Training.completed_workout_dates_with_counts(scope, start_of_month, end_of_month)
      |> Map.new(fn %{date: date, count: count} -> {date, count} end)

    padding = Date.day_of_week(start_of_month) - 1
    days = Date.days_in_month(current_month)

    leading = blank_days(padding)

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

    leading ++ current ++ blank_days(trailing_count)
  end

  defp blank_days(count) when count <= 0, do: []

  defp blank_days(count) do
    for _ <- 1..count do
      %{date: nil, day: nil, has_workout: false, is_today: false, workout_count: 0}
    end
  end

  defp summary_stats(scope) do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today)
    end_of_week = Date.end_of_week(today)
    current_month = Date.beginning_of_month(today)
    month_workouts = completed_workouts_for_month(scope, current_month)

    %{
      workouts_this_week:
        scope
        |> Training.list_completed_workouts_in_date_range(start_of_week, end_of_week)
        |> length(),
      average_duration: average_duration(month_workouts),
      total_volume: month_workouts |> total_volume_decimal() |> decimal_text(),
      streak_days: current_streak_days(scope)
    }
  end

  defp monthly_stats(scope, current_month) do
    workouts = completed_workouts_for_month(scope, current_month)
    total_workouts = length(workouts)

    weeks_in_month =
      current_month
      |> Date.days_in_month()
      |> Kernel./(7)

    %{
      total_workouts: total_workouts,
      total_volume: workouts |> total_volume_decimal() |> decimal_text(),
      avg_workouts_per_week: Float.round(total_workouts / max(weeks_in_month, 1), 1)
    }
  end

  defp completed_workouts_for_month(scope, current_month) do
    Training.list_completed_workouts_in_date_range(
      scope,
      Date.beginning_of_month(current_month),
      Date.end_of_month(current_month)
    )
  end

  defp load_workouts_for_date(scope, date) do
    Training.list_completed_workouts_in_date_range(scope, date, date)
  end

  defp shift_month(date, amount) do
    month_index = date.month - 1 + amount
    year = date.year + div(month_index, 12)
    month = rem(month_index, 12)
    month = if month < 0, do: month + 12, else: month
    Date.new!(year, month + 1, 1)
  end

  defp workout_name(workout), do: "Workout on #{Calendar.strftime(workout.started_at, "%A")}"

  defp linked_plan_name(_workout), do: "Not linked"

  defp workout_exercise_count(workout) do
    workout.workout_sets
    |> Enum.map(& &1.exercise_id)
    |> Enum.uniq()
    |> length()
  end

  defp workout_reps(workout) do
    Enum.reduce(workout.workout_sets, 0, &(&2 + (&1.reps || 0)))
  end

  defp format_workout_duration(workout) do
    case Enum.map(workout.workout_sets, & &1.inserted_at) do
      [] ->
        "0m"

      [_single] ->
        "0m"

      timestamps ->
        "#{max(DateTime.diff(Enum.max(timestamps), Enum.min(timestamps), :minute), 0)}m"
    end
  end

  defp average_duration([]), do: "0m"

  defp average_duration(workouts) do
    total_minutes =
      workouts
      |> Enum.map(&workout_duration_minutes/1)
      |> Enum.sum()

    "#{round(total_minutes / length(workouts))}m"
  end

  defp workout_duration_minutes(workout) do
    case Enum.map(workout.workout_sets, & &1.inserted_at) do
      [] -> 0
      [_single] -> 0
      timestamps -> max(DateTime.diff(Enum.max(timestamps), Enum.min(timestamps), :minute), 0)
    end
  end

  defp format_workout_volume(workout) do
    workout
    |> workout_volume_decimal()
    |> decimal_text()
  end

  defp total_volume_decimal(workouts) do
    Enum.reduce(workouts, Decimal.new(0), &Decimal.add(&2, workout_volume_decimal(&1)))
  end

  defp workout_volume_decimal(workout) do
    Enum.reduce(workout.workout_sets, Decimal.new(0), fn set, acc ->
      Decimal.add(acc, Decimal.mult(set.weight || Decimal.new(0), Decimal.new(set.reps || 0)))
    end)
  end

  defp current_streak_days(scope) do
    completed_dates = scope |> Training.list_completed_workout_dates() |> MapSet.new()
    count_streak(Date.utc_today(), completed_dates, 0)
  end

  defp count_streak(date, completed_dates, count) do
    if MapSet.member?(completed_dates, date) do
      count_streak(Date.add(date, -1), completed_dates, count + 1)
    else
      count
    end
  end

  defp decimal_text(%Decimal{} = value) do
    value
    |> Decimal.round(1)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end
end
