defmodule FittrackWeb.WorkoutHistoryLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Workout History</h1>
            <p class="text-sm text-base-content/70">
              View your completed workout sessions in a calendar format.
            </p>
          </div>
          <div class="flex gap-2">
            <.link navigate={~p"/dashboard"} class="btn btn-outline">
              <.icon name="hero-chart-bar" class="h-5 w-5" /> Dashboard
            </.link>
            <.link navigate={~p"/workouts/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="h-5 w-5" /> Start Workout
            </.link>
          </div>
        </div>
        
    <!-- Month Navigation -->
        <div class="flex items-center justify-between">
          <button phx-click="previous_month" class="btn btn-ghost btn-sm">
            <.icon name="hero-chevron-left" class="h-5 w-5" />
          </button>

          <h2 class="text-xl font-semibold text-base-content">
            {Calendar.strftime(@current_date, "%B %Y")}
          </h2>

          <button phx-click="next_month" class="btn btn-ghost btn-sm">
            <.icon name="hero-chevron-right" class="h-5 w-5" />
          </button>
        </div>
        
    <!-- Calendar Grid -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <!-- Day Headers -->
          <div class="grid grid-cols-7 gap-2 mb-4">
            <%= for day_name <- ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] do %>
              <div class="p-2 text-center text-sm font-medium text-base-content/70">
                {day_name}
              </div>
            <% end %>
          </div>
          
    <!-- Calendar Days -->
          <div class="grid grid-cols-7 gap-2">
            <%= for day_info <- @calendar_days do %>
              <div
                class={[
                  "aspect-square p-2 text-center text-sm rounded-lg border transition cursor-pointer",
                  if(day_info.has_workout,
                    do: "bg-primary text-white border-primary hover:bg-primary/90",
                    else: "border-base-200 hover:border-base-300 hover:bg-base-50"
                  ),
                  if(day_info.is_today, do: "ring-2 ring-primary/50", else: "")
                ]}
                phx-click="select_date"
                phx-value-date={day_info.date}
              >
                <div class="font-medium">{day_info.day}</div>
                <%= if day_info.has_workout do %>
                  <div class="text-xs mt-1 opacity-90">
                    {day_info.workout_count} workout{if day_info.workout_count != 1, do: "s", else: ""}
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Selected Date Workouts -->
        <%= if @selected_date do %>
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">
              Workouts on {Calendar.strftime(@selected_date, "%B %d, %Y")}
            </h3>

            <%= if Enum.empty?(@selected_date_workouts) do %>
              <p class="text-base-content/70 text-center py-8">No workouts on this date.</p>
            <% else %>
              <div class="space-y-4">
                <%= for workout <- @selected_date_workouts do %>
                  <div class="flex items-center justify-between p-4 border border-base-200 rounded-lg hover:border-primary/20 transition">
                    <div>
                      <p class="font-medium text-base-content">
                        Workout at {Calendar.strftime(workout.started_at, "%I:%M %p")}
                      </p>
                      <%= if workout.notes do %>
                        <p class="text-sm text-base-content/70 mt-1">{workout.notes}</p>
                      <% end %>
                      <div class="flex items-center gap-4 mt-2 text-sm text-base-content/60">
                        <.icon name="hero-queue-list" class="h-4 w-4" />
                        <span>{length(workout.workout_sets)} sets</span>
                        <.icon name="hero-scale" class="h-4 w-4 ml-2" />
                        <span>{calculate_workout_volume(workout)} lbs total</span>
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <.link navigate={~p"/workouts/#{workout}"} class="btn btn-outline btn-sm">
                        View Details
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Monthly Summary -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <h3 class="text-lg font-semibold text-base-content mb-4">
            {Calendar.strftime(@current_date, "%B %Y")} Summary
          </h3>

          <div class="grid gap-4 md:grid-cols-3">
            <div class="text-center">
              <p class="text-2xl font-bold text-primary">{@monthly_stats.total_workouts}</p>
              <p class="text-sm text-base-content/70">Total Workouts</p>
            </div>
            <div class="text-center">
              <p class="text-2xl font-bold text-primary">{@monthly_stats.total_volume} lbs</p>
              <p class="text-sm text-base-content/70">Total Volume</p>
            </div>
            <div class="text-center">
              <p class="text-2xl font-bold text-primary">{@monthly_stats.avg_workouts_per_week}</p>
              <p class="text-sm text-base-content/70">Avg Workouts/Week</p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_date = Date.utc_today()

    {:ok,
     socket
     |> assign(:page_title, "Workout History")
     |> assign(:current_date, current_date)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> assign(:calendar_days, load_calendar_days(socket.assigns.current_scope, current_date))
     |> assign(:monthly_stats, load_monthly_stats(socket.assigns.current_scope, current_date))}
  end

  @impl true
  def handle_event("previous_month", _params, socket) do
    new_date = Date.add(socket.assigns.current_date, -30) |> Date.beginning_of_month()

    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> assign(:calendar_days, load_calendar_days(socket.assigns.current_scope, new_date))
     |> assign(:monthly_stats, load_monthly_stats(socket.assigns.current_scope, new_date))}
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    new_date = Date.add(socket.assigns.current_date, 30) |> Date.beginning_of_month()

    {:noreply,
     socket
     |> assign(:current_date, new_date)
     |> assign(:selected_date, nil)
     |> assign(:selected_date_workouts, [])
     |> assign(:calendar_days, load_calendar_days(socket.assigns.current_scope, new_date))
     |> assign(:monthly_stats, load_monthly_stats(socket.assigns.current_scope, new_date))}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_str}, socket) do
    selected_date = Date.from_iso8601!(date_str)
    workouts = load_workouts_for_date(socket.assigns.current_scope, selected_date)

    {:noreply,
     socket
     |> assign(:selected_date, selected_date)
     |> assign(:selected_date_workouts, workouts)}
  end

  defp load_calendar_days(scope, current_date) do
    start_of_month = Date.beginning_of_month(current_date)
    end_of_month = Date.end_of_month(current_date)
    today = Date.utc_today()

    # Get workout data for this month
    workout_data =
      Training.workout_dates_in_month_with_counts(scope, start_of_month, end_of_month)

    workout_data_map = Map.new(workout_data, fn %{date: date, count: count} -> {date, count} end)

    start_day_of_week = Date.day_of_week(start_of_month)
    total_days = Date.days_in_month(end_of_month)

    # Add padding days from previous month
    padding_days = if start_day_of_week == 7, do: 0, else: start_day_of_week

    calendar_days = []

    # Add padding days
    calendar_days =
      calendar_days ++
        for _ <- 1..padding_days do
          %{day: "", has_workout: false, is_today: false, date: nil, workout_count: 0}
        end

    # Add actual days
    calendar_days =
      calendar_days ++
        for day <- 1..total_days do
          date = Date.new!(current_date.year, current_date.month, day)
          workout_count = Map.get(workout_data_map, date, 0)

          %{
            day: day,
            has_workout: workout_count > 0,
            is_today: date == today,
            date: date,
            workout_count: workout_count
          }
        end

    calendar_days
  end

  defp load_monthly_stats(scope, current_date) do
    start_of_month = Date.beginning_of_month(current_date)
    end_of_month = Date.end_of_month(current_date)

    # Get workouts for the month
    workouts = Training.list_workouts_in_date_range(scope, start_of_month, end_of_month)

    total_workouts = length(workouts)
    total_volume = Enum.sum(Enum.map(workouts, &calculate_workout_volume/1))

    # Calculate weeks in month (approximate)
    days_in_month = Date.days_in_month(current_date)

    avg_workouts_per_week =
      if days_in_month > 0, do: Float.round(total_workouts / (days_in_month / 7), 1), else: 0

    %{
      total_workouts: total_workouts,
      total_volume: total_volume,
      avg_workouts_per_week: avg_workouts_per_week
    }
  end

  defp load_workouts_for_date(scope, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    Training.list_workouts_in_date_range(scope, start_of_day, end_of_day)
  end

  defp calculate_workout_volume(workout) do
    Enum.sum(
      Enum.map(workout.workout_sets, fn set ->
        Decimal.to_float(set.weight || 0) * (set.reps || 0)
      end)
    )
    |> round()
  end
end
