defmodule FittrackWeb.DashboardLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Dashboard</h1>
            <p class="text-sm text-base-content/70">
              Track your progress and visualize your fitness journey.
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <%= if @active_workout do %>
              <.link
                id="dashboard-resume-workout-link"
                navigate={~p"/workouts/#{@active_workout}"}
                class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
              >
                <.icon name="hero-play" class="mr-2 h-4 w-4" /> Resume workout
              </.link>
            <% else %>
              <.link
                id="dashboard-start-workout-link"
                navigate={~p"/workouts/new"}
                class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
              >
                <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Start workout
              </.link>
              <.link
                id="dashboard-browse-plans-link"
                navigate={~p"/workout-plans"}
                class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              >
                <.icon name="hero-clipboard-document-list" class="mr-2 h-4 w-4" /> Browse plans
              </.link>
            <% end %>
          </div>
        </div>
        
    <!-- Stats Overview -->
        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-trophy" class="h-8 w-8 text-yellow-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Personal Bests</p>
                <p class="text-2xl font-bold text-base-content">{@stats.total_personal_bests}</p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-scale" class="h-8 w-8 text-blue-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Total Volume</p>
                <p class="text-2xl font-bold text-base-content">
                  {format_weight(@stats.total_volume)} lbs
                </p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-calendar-days" class="h-8 w-8 text-green-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">Workouts</p>
                <p class="text-2xl font-bold text-base-content">{@stats.total_sessions}</p>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex items-center gap-3">
              <.icon name="hero-clock" class="h-8 w-8 text-purple-500" />
              <div>
                <p class="text-sm font-medium text-base-content/70">This Week</p>
                <p class="text-2xl font-bold text-base-content">{@stats.weekly_sessions}</p>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Charts Row -->
        <div class="grid gap-6 lg:grid-cols-2">
          <!-- Personal Bests Chart -->
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">Personal Bests by Exercise</h3>
            <div class="h-80">
              <canvas
                id="personal-bests-chart"
                phx-hook="PersonalBestsChart"
                data-chart-data={Jason.encode!(@personal_bests_chart)}
              >
              </canvas>
            </div>
          </div>
          
    <!-- Volume Over Time Chart -->
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold text-base-content mb-4">Volume Over Time</h3>
            <div class="h-80">
              <canvas
                id="volume-chart"
                phx-hook="VolumeChart"
                data-chart-data={Jason.encode!(@volume_chart)}
              >
              </canvas>
            </div>
          </div>
        </div>
        
    <!-- Exercise Progress -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <h3 class="text-lg font-semibold text-base-content">Exercise Progress</h3>
              <p class="text-sm text-base-content/70">
                Select an exercise to see how your average weight is trending over time.
              </p>
            </div>
            <form id="exercise-progress-form" phx-change="select_exercise" class="w-48">
              <label class="block">
                <span class="sr-only">Exercise</span>
                <select
                  name="exercise_id"
                  class="mt-1 block w-full rounded-lg border border-base-300 px-3 py-2 text-sm"
                  value={@selected_exercise_id}
                >
                  <%= for exercise <- @exercises do %>
                    <option value={exercise.id} selected={exercise.id == @selected_exercise_id}>
                      {exercise.name}
                    </option>
                  <% end %>
                </select>
              </label>
            </form>
          </div>

          <div class="h-80 mt-4">
            <canvas
              id="exercise-progress-chart"
              phx-hook="ExerciseProgressChart"
              data-chart-data={Jason.encode!(@exercise_progress_chart)}
            >
            </canvas>
          </div>

          <div class="mt-5">
            <h4 class="text-sm font-semibold">Quick log</h4>
            <form phx-submit="log_exercise" class="grid gap-3 md:grid-cols-4">
              <label class="block">
                <span class="text-xs text-base-content/70">Exercise</span>
                <select
                  name="performance[exercise_id]"
                  class="mt-1 block w-full rounded-lg border border-base-300 px-3 py-2 text-sm"
                >
                  <%= for exercise <- @exercises do %>
                    <option value={exercise.id}>{exercise.name}</option>
                  <% end %>
                </select>
              </label>

              <label class="block">
                <span class="text-xs text-base-content/70">Weight</span>
                <input
                  name="performance[weight]"
                  type="number"
                  step="0.5"
                  class="mt-1 block w-full rounded-lg border border-base-300 px-3 py-2 text-sm"
                />
              </label>

              <label class="block">
                <span class="text-xs text-base-content/70">Reps</span>
                <input
                  name="performance[reps]"
                  type="number"
                  class="mt-1 block w-full rounded-lg border border-base-300 px-3 py-2 text-sm"
                />
              </label>

              <button type="submit" class="btn btn-primary mt-6">Log Set</button>
            </form>
          </div>
        </div>
        
    <!-- Recent Personal Bests -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <h3 class="text-lg font-semibold text-base-content mb-4">Recent Personal Bests</h3>
          <div class="space-y-3">
            <%= for pb <- @recent_personal_bests do %>
              <div class="flex items-center justify-between p-3 rounded-lg bg-base-50">
                <div>
                  <p class="font-medium text-base-content">{pb.exercise_name}</p>
                  <p class="text-sm text-base-content/70">
                    {pb.date |> Calendar.strftime("%B %d, %Y")}
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold text-primary">{format_weight(pb.weight)} lbs</p>
                  <p class="text-sm text-base-content/70">{pb.reps} reps</p>
                </div>
              </div>
            <% end %>
          </div>
          <%= if Enum.empty?(@recent_personal_bests) do %>
            <p class="text-base-content/70 text-center py-8">No personal bests recorded yet.</p>
          <% end %>
        </div>
        
    <!-- Workout Calendar -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <h3 class="text-lg font-semibold text-base-content mb-4">Workout Calendar</h3>
          <div class="grid grid-cols-7 gap-2 mb-4">
            <%= for day <- ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] do %>
              <div class="p-2 text-center text-sm font-medium text-base-content/70">
                {day}
              </div>
            <% end %>
          </div>
          <div class="grid grid-cols-7 gap-2">
            <%= for day <- @calendar_days do %>
              <div class={[
                "aspect-square p-2 text-center text-sm rounded-lg border transition",
                if(day.has_workout,
                  do: "bg-primary text-white border-primary",
                  else: "border-base-200 hover:border-base-300"
                )
              ]}>
                {day.day}
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    exercises = Training.list_exercises(current_scope)
    selected_exercise_id = exercises |> List.first() |> then(&(&1 && &1.id))

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:active_workout, Training.get_active_workout(current_scope))
     |> assign(:stats, load_stats(current_scope))
     |> assign(:exercises, exercises)
     |> assign(:selected_exercise_id, selected_exercise_id)
     |> assign(:personal_bests_chart, load_personal_bests_chart(current_scope))
     |> assign(:volume_chart, load_volume_chart(current_scope))
     |> assign(
       :exercise_progress_chart,
       load_exercise_progress_chart(current_scope, selected_exercise_id)
     )
     |> assign(:recent_personal_bests, load_recent_personal_bests(current_scope))
     |> assign(:calendar_days, load_calendar_days(current_scope))}
  end

  defp load_stats(scope) do
    %{
      total_personal_bests: Training.count_personal_bests(scope),
      total_volume: Training.total_volume_lifted(scope),
      total_sessions: Training.count_workouts(scope),
      weekly_sessions: Training.count_weekly_workouts(scope)
    }
  end

  defp load_personal_bests_chart(scope) do
    personal_bests = Training.list_personal_bests(scope)

    %{
      labels: Enum.map(personal_bests, & &1.exercise_name),
      datasets: [
        %{
          label: "Personal Best (lbs)",
          data: Enum.map(personal_bests, & &1.weight),
          backgroundColor: "rgba(59, 130, 246, 0.5)",
          borderColor: "rgba(59, 130, 246, 1)",
          borderWidth: 1
        }
      ]
    }
  end

  defp load_volume_chart(scope) do
    volume_data = Training.volume_over_time(scope)

    %{
      labels: Enum.map(volume_data, & &1.date),
      datasets: [
        %{
          label: "Volume (lbs)",
          data: Enum.map(volume_data, & &1.volume),
          backgroundColor: "rgba(16, 185, 129, 0.5)",
          borderColor: "rgba(16, 185, 129, 1)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp load_exercise_progress_chart(_scope, nil) do
    %{labels: [], datasets: []}
  end

  defp load_exercise_progress_chart(scope, exercise_id) do
    progress_data = Training.exercise_progress_over_time(scope, exercise_id)

    %{
      labels: Enum.map(progress_data, &Calendar.strftime(&1.date, "%b %d")),
      datasets: [
        %{
          label: "Average weight",
          data: Enum.map(progress_data, & &1.avg_weight),
          borderColor: "rgba(59, 130, 246, 1)",
          backgroundColor: "rgba(59, 130, 246, 0.25)",
          borderWidth: 2,
          fill: true
        }
      ]
    }
  end

  defp load_recent_personal_bests(scope) do
    Training.recent_personal_bests(scope, limit: 5)
  end

  defp load_calendar_days(scope) do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    end_of_month = Date.end_of_month(today)

    # Get workout dates for this month
    workout_dates = Training.workout_dates_in_month(scope, start_of_month, end_of_month)
    workout_date_set = MapSet.new(workout_dates)

    # Generate calendar days
    start_day_of_week = Date.day_of_week(start_of_month)
    total_days = Date.days_in_month(end_of_month)

    # Add padding days from previous month
    padding_days = if start_day_of_week == 7, do: 0, else: start_day_of_week

    calendar_days = []

    # Add padding days
    calendar_days =
      calendar_days ++
        for _ <- 1..padding_days do
          %{day: "", has_workout: false}
        end

    # Add actual days
    calendar_days =
      calendar_days ++
        for day <- 1..total_days do
          date = Date.new!(today.year, today.month, day)
          %{day: day, has_workout: MapSet.member?(workout_date_set, date)}
        end

    calendar_days
  end

  @impl true
  def handle_event("select_exercise", %{"exercise_id" => exercise_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_exercise_id, String.to_integer(exercise_id))
     |> assign(
       :exercise_progress_chart,
       load_exercise_progress_chart(socket.assigns.current_scope, String.to_integer(exercise_id))
     )}
  end

  @impl true
  def handle_event(
        "log_exercise",
        %{"performance" => %{"exercise_id" => exercise_id, "weight" => weight, "reps" => reps}},
        socket
      ) do
    case Training.log_exercise_set(socket.assigns.current_scope, %{
           "exercise_id" => exercise_id,
           "weight" => weight,
           "reps" => reps
         }) do
      {:ok, _workout_set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Performance logged successfully")
         |> assign(:stats, load_stats(socket.assigns.current_scope))
         |> assign(
           :exercise_progress_chart,
           load_exercise_progress_chart(
             socket.assigns.current_scope,
             String.to_integer(exercise_id)
           )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not log performance. Please try again.")}
    end
  end

  defp format_weight(weight) when is_float(weight), do: Float.round(weight, 1)
  defp format_weight(weight), do: weight
end
