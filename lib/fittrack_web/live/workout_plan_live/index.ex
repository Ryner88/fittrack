defmodule FittrackWeb.WorkoutPlanLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Workout Plans</h1>
            <p class="text-sm text-base-content/70">
              Create and manage workout templates for consistent training routines.
            </p>
          </div>
          <.link
            navigate={~p"/workout-plans/new"}
            class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
          >
            <.icon name="hero-plus" class="mr-2 size-4" /> Create plan
          </.link>
        </div>

        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          <%= for workout_plan <- @workout_plans do %>
            <.workout_plan_card workout_plan={workout_plan} />
          <% end %>
        </div>

        <%= if Enum.empty?(@workout_plans) do %>
          <div class="text-center py-12">
            <div class="text-base-content/50">
              <.icon name="hero-document-text" class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-base-content">No workout plans yet</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Create your first workout plan to get started.
              </p>
              <div class="mt-6">
                <.link
                  navigate={~p"/workout-plans/new"}
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
     |> assign(:page_title, "Workout Plans")
     |> assign(:workout_plans, list_workout_plans(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    workout_plan = Training.get_workout_plan!(socket.assigns.current_scope, id)
    {:ok, _} = Training.delete_workout_plan(socket.assigns.current_scope, workout_plan)

    {:noreply,
     socket
     |> assign(:workout_plans, list_workout_plans(socket.assigns.current_scope))
     |> put_flash(:info, "Workout plan deleted successfully")}
  end

  @impl true
  def handle_event("start_session", %{"id" => id}, socket) do
    {:ok, workout} = Training.create_workout_from_plan(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> put_flash(:info, "Workout started from plan")
     |> push_navigate(to: ~p"/workouts/#{workout}")}
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    workout_plan = Training.get_workout_plan!(socket.assigns.current_scope, id)

    # Create a duplicate with "Copy of" prefix
    attrs = %{
      name: "Copy of #{workout_plan.name}",
      description: workout_plan.description,
      workout_plan_exercises:
        Enum.map(workout_plan.workout_plan_exercises, fn exercise ->
          %{
            exercise_id: exercise.exercise_id,
            sets: exercise.sets,
            reps: exercise.reps,
            rest_seconds: exercise.rest_seconds
          }
        end)
    }

    case Training.create_workout_plan(socket.assigns.current_scope, attrs) do
      {:ok, _new_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout plan duplicated successfully")
         |> assign(:workout_plans, list_workout_plans(socket.assigns.current_scope))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to duplicate workout plan")}
    end
  end

  defp list_workout_plans(current_scope) do
    Training.list_workout_plans(current_scope)
  end

  attr :workout_plan, :map, required: true

  defp workout_plan_card(assigns) do
    ~H"""
    <div class="group relative rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm transition hover:shadow-md hover:border-primary/20">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h3 class="font-semibold text-base-content group-hover:text-primary transition">
            {@workout_plan.name}
          </h3>
          <%= if @workout_plan.description do %>
            <p class="text-sm text-base-content/70 mt-1 line-clamp-2">
              {@workout_plan.description}
            </p>
          <% end %>
          <div class="mt-3 flex items-center gap-4 text-sm text-base-content/60">
            <.icon name="hero-queue-list" class="h-4 w-4" />
            <span>{length(@workout_plan.workout_plan_exercises)} exercises</span>
            <.icon name="hero-clock" class="h-4 w-4 ml-2" />
            <span>~{estimate_duration(@workout_plan)}m</span>
          </div>
        </div>
      </div>

      <div class="mt-6 flex items-center justify-between">
        <div class="flex gap-2">
          <.link
            navigate={~p"/workout-plans/#{@workout_plan}"}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-eye" class="h-3 w-3" /> View
          </.link>
          <.link
            navigate={~p"/workout-plans/#{@workout_plan}/edit"}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-pencil" class="h-3 w-3" /> Edit
          </.link>
          <button
            phx-click="duplicate"
            phx-value-id={@workout_plan.id}
            class="inline-flex items-center gap-2 rounded-lg border border-base-300 px-3 py-1.5 text-xs font-medium text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-document-duplicate" class="h-3 w-3" /> Duplicate
          </button>
        </div>
        <div class="flex gap-2">
          <button
            phx-click="start_session"
            phx-value-id={@workout_plan.id}
            class="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-white shadow-sm transition hover:bg-primary/90"
          >
            <.icon name="hero-play" class="h-3 w-3" /> Start workout
          </button>
          <button
            phx-click="delete"
            phx-value-id={@workout_plan.id}
            data-confirm="Are you sure you want to delete this workout plan?"
            class="inline-flex items-center gap-2 rounded-lg border border-rose-300 px-3 py-1.5 text-xs font-medium text-rose-600 transition hover:bg-rose-50"
          >
            <.icon name="hero-trash" class="h-3 w-3" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp estimate_duration(workout_plan) do
    # Rough estimate: 45 seconds per set + rest time between sets
    total_sets = Enum.sum(Enum.map(workout_plan.workout_plan_exercises, & &1.sets))

    total_rest_seconds =
      Enum.sum(Enum.map(workout_plan.workout_plan_exercises, &(&1.rest_seconds * &1.sets)))

    # Assume 45 seconds per set + rest time, convert to minutes
    total_seconds = total_sets * 45 + total_rest_seconds
    max(1, div(total_seconds, 60))
  end
end
