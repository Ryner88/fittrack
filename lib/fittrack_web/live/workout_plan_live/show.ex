defmodule FittrackWeb.WorkoutPlanLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto space-y-8">
        <!-- Header -->
        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-3xl font-bold text-base-content">{@workout_plan.name}</h1>
            <%= if @workout_plan.description do %>
              <p class="text-lg text-base-content/70 mt-2">{@workout_plan.description}</p>
            <% end %>
            <div class="mt-4 flex items-center gap-4 text-sm text-base-content/60">
              <.icon name="hero-queue-list" class="h-5 w-5" />
              <span>{length(@workout_plan.workout_plan_exercises)} exercises</span>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <button
              phx-click="start_session"
              phx-value-id={@workout_plan.id}
              class="inline-flex items-center gap-2 rounded-full bg-primary px-6 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
            >
              <.icon name="hero-play" class="h-5 w-5" /> Start Workout
            </button>
          </div>
        </div>
        
    <!-- Actions -->
        <div class="flex gap-3">
          <.link
            navigate={~p"/workout-plans/#{@workout_plan}/edit"}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-4 py-2 text-sm font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-pencil" class="h-4 w-4" /> Edit Plan
          </.link>
          <button
            phx-click="delete"
            phx-value-id={@workout_plan.id}
            data-confirm="Are you sure you want to delete this workout plan?"
            class="inline-flex items-center gap-2 rounded-lg border border-rose-300 px-4 py-2 text-sm font-medium text-rose-600 transition hover:bg-rose-50"
          >
            <.icon name="hero-trash" class="h-4 w-4" /> Delete Plan
          </button>
        </div>
        
    <!-- Exercises -->
        <div class="space-y-4">
          <%= for {plan_exercise, index} <- Enum.with_index(@workout_plan.workout_plan_exercises) do %>
            <.exercise_card exercise={plan_exercise} index={index} />
          <% end %>
        </div>

        <%= if Enum.empty?(@workout_plan.workout_plan_exercises) do %>
          <div class="text-center py-12">
            <div class="text-base-content/50">
              <.icon name="hero-queue-list" class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-base-content">No exercises in this plan</h3>
              <p class="mt-1 text-sm text-base-content/70">Add some exercises to get started.</p>
              <div class="mt-6">
                <.link
                  navigate={~p"/workout-plans/#{@workout_plan}/edit"}
                  class="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> Add Exercises
                </.link>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Back to Plans -->
        <div class="flex justify-center">
          <.link
            navigate={~p"/workout-plans"}
            class="inline-flex items-center gap-2 text-primary hover:text-primary/80 transition"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to Workout Plans
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workout Plan")
     |> assign(:workout_plan, Training.get_workout_plan!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_event("start_session", %{"id" => id}, socket) do
    {:ok, workout} = Training.create_workout_from_plan(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> put_flash(:info, "Workout session started from plan")
     |> push_navigate(to: ~p"/workouts/#{workout}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    workout_plan = Training.get_workout_plan!(socket.assigns.current_scope, id)
    {:ok, _} = Training.delete_workout_plan(socket.assigns.current_scope, workout_plan)

    {:noreply,
     socket
     |> put_flash(:info, "Workout plan deleted successfully")
     |> push_navigate(to: ~p"/workout-plans")}
  end

  attr :exercise, :map, required: true
  attr :index, :integer, required: true

  defp exercise_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
      <div class="flex items-start gap-4">
        <!-- Order indicator -->
        <div class="flex items-center justify-center w-10 h-10 rounded-full bg-primary text-white font-semibold">
          {@exercise.position}
        </div>
        
    <!-- Exercise details -->
        <div class="flex-1">
          <h3 class="text-lg font-semibold text-base-content">
            {@exercise.exercise.name}
          </h3>
          <p class="text-sm text-base-content/70 mt-1">
            {@exercise.exercise.primary_muscle} • {@exercise.exercise.equipment}
          </p>
          
    <!-- Sets, reps, rest -->
          <div class="mt-4 grid grid-cols-3 gap-4">
            <div class="text-center">
              <div class="text-2xl font-bold text-primary">{@exercise.target_sets}</div>
              <div class="text-xs text-base-content/60 uppercase tracking-wide">Sets</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-primary">
                {@exercise.target_reps_min}-{@exercise.target_reps_max}
              </div>
              <div class="text-xs text-base-content/60 uppercase tracking-wide">Reps</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-primary">
                {format_rest_time(@exercise.rest_seconds)}
              </div>
              <div class="text-xs text-base-content/60 uppercase tracking-wide">Rest</div>
            </div>
          </div>
          
    <!-- Notes -->
          <%= if @exercise.notes && @exercise.notes != "" do %>
            <div class="mt-4 p-3 rounded-lg bg-base-200/50">
              <p class="text-sm text-base-content/80">{@exercise.notes}</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_rest_time(seconds) do
    cond do
      seconds >= 60 ->
        minutes = div(seconds, 60)
        remaining_seconds = rem(seconds, 60)

        if remaining_seconds == 0 do
          "#{minutes}m"
        else
          "#{minutes}m #{remaining_seconds}s"
        end

      true ->
        "#{seconds}s"
    end
  end
end
