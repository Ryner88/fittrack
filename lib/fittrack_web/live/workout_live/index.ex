defmodule FittrackWeb.WorkoutLive.Index do
  use FittrackWeb, :live_view

  alias Decimal
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
              Review completed workouts, track performance, and continue workouts in progress.
            </p>
          </div>
          <.link
            navigate={~p"/workouts/new"}
            class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
          >
            Start workout
          </.link>
        </div>

        <div id="workout-sessions" phx-update="stream" class="space-y-6">
          <!-- In Progress Section -->
          <div class="space-y-4">
            <h2 class="text-lg font-semibold text-base-content">In Progress</h2>
            <div class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100 p-6 text-center">
              <p class="text-sm font-semibold text-base-content">No workouts in progress.</p>
              <p class="mt-1 text-sm text-base-content/70">
                Start a workout to see it here.
              </p>
            </div>
            <div
              :for={{id, workout} <- @streams.in_progress_workouts}
              id={id}
              class="group rounded-2xl border border-primary/25 bg-primary/5 p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40 sm:p-6"
            >
              <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
                <div class="flex items-center gap-4 sm:min-w-28">
                  <div class="flex flex-row items-baseline gap-2 sm:flex-col sm:gap-0">
                    <p class="text-sm font-medium text-base-content">
                      {Calendar.strftime(workout.started_at, "%b %d")}
                    </p>
                    <p class="text-xs text-base-content/60">
                      {Calendar.strftime(workout.started_at, "%Y")}
                    </p>
                  </div>
                  <div class="hidden h-8 w-px bg-primary/30 sm:block"></div>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="font-medium text-base-content">
                    Workout in progress
                  </p>
                  <p class="text-sm text-base-content/70">
                    Started {format_started_at(workout.started_at)} • {length(workout.workout_sets)} sets completed
                  </p>
                </div>
                <div class="flex flex-wrap items-center gap-3 sm:justify-end">
                  <span class="inline-flex items-center rounded-full border border-primary/20 bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary">
                    In Progress
                  </span>
                  <.link
                    navigate={~p"/workouts/#{workout}"}
                    class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-3 py-1.5 text-sm font-medium text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                  >
                    Continue workout
                  </.link>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Workout History Section -->
          <div class="space-y-4">
            <h2 class="text-lg font-semibold text-base-content">Workout History</h2>
            <div class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100 p-6 text-center">
              <p class="text-sm font-semibold text-base-content">No completed workouts yet.</p>
              <p class="mt-1 text-sm text-base-content/70">
                Your completed workouts will appear here.
              </p>
            </div>
            <div
              :for={{id, workout} <- @streams.completed_workouts}
              id={id}
              class="group rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md sm:p-6"
            >
              <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
                <div class="flex items-center gap-4 sm:min-w-28">
                  <div class="flex flex-row items-baseline gap-2 sm:flex-col sm:gap-0">
                    <p class="text-sm font-medium text-base-content">
                      {Calendar.strftime(workout.started_at, "%b %d")}
                    </p>
                    <p class="text-xs text-base-content/60">
                      {Calendar.strftime(workout.started_at, "%Y")}
                    </p>
                  </div>
                  <div class="hidden h-8 w-px bg-base-300 sm:block"></div>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="font-medium text-base-content">
                    Workout on {Calendar.strftime(workout.started_at, "%A")}
                  </p>
                  <p class="text-sm text-base-content/70">
                    {format_duration(workout)} • {format_volume(workout)} lbs • {length(
                      workout.workout_sets
                    )} sets
                  </p>
                </div>
                <div class="flex flex-wrap items-center gap-3 sm:justify-end">
                  <span class="inline-flex items-center rounded-full border border-success/20 bg-success/10 px-2.5 py-1 text-xs font-semibold text-success">
                    Completed
                  </span>
                  <.link
                    navigate={~p"/workouts/#{workout}"}
                    class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-3 py-1.5 text-sm font-medium text-base-content transition hover:border-primary hover:text-primary"
                  >
                    View details
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    workouts = Training.list_workouts(socket.assigns.current_scope)

    {in_progress, completed} =
      Enum.split_with(workouts, fn workout ->
        session_status(workout) == "Planned"
      end)

    {:ok,
     socket
     |> assign(:page_title, "Workout History")
     |> stream(:in_progress_workouts, in_progress)
     |> stream(:completed_workouts, completed)}
  end

  defp format_started_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y • %H:%M")
  end

  defp session_sets(session), do: session.workout_sets || []

  defp format_duration(session) do
    sets = session_sets(session)

    case sets do
      [] ->
        "0m"

      _ ->
        timestamps = Enum.map(sets, & &1.inserted_at)
        duration_min = DateTime.diff(Enum.max(timestamps), Enum.min(timestamps), :minute)
        "#{max(duration_min, 0)}m"
    end
  end

  defp format_volume(session) do
    session_sets(session)
    |> Enum.reduce(Decimal.new(0), fn set, acc ->
      weight = set.weight || Decimal.new(0)
      reps = set.reps || 0

      acc
      |> Decimal.add(Decimal.mult(weight, Decimal.new(reps)))
    end)
    |> Decimal.to_string(:normal)
  end

  defp session_status(session) do
    if Enum.any?(session_sets(session)) do
      "Completed"
    else
      "Planned"
    end
  end
end
