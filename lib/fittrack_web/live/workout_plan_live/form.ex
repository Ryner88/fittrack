defmodule FittrackWeb.WorkoutPlanLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto space-y-8">
        <.header>
          {@page_title}
          <:subtitle>
            {@live_action == :new &&
              "Create a new workout plan by selecting exercises from your library."}
            {@live_action == :edit && "Edit your workout plan and modify the exercise sequence."}
          </:subtitle>
          <:actions>
            <.link navigate={~p"/workout-plans"} class="btn btn-ghost">
              <.icon name="hero-arrow-left" /> Back to plans
            </.link>
          </:actions>
        </.header>

        <.form for={@form} id="workout-plan-form" phx-submit="save" phx-change="validate">
          <div class="space-y-8">
            <!-- Basic Info -->
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
              <h3 class="text-lg font-semibold text-base-content mb-4">Plan Details</h3>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@form[:name]} type="text" label="Plan Name" required />
                <.input field={@form[:description]} type="textarea" label="Description" rows="3" />
              </div>
            </div>
            
    <!-- Exercises -->
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-base-content">Exercises</h3>
                <button
                  type="button"
                  phx-click="add_exercise"
                  class="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-2 text-sm font-medium text-white shadow-sm transition hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="h-4 w-4" /> Add Exercise
                </button>
              </div>

              <div id="exercises-list" class="space-y-4">
                <.inputs_for :let={exercise_form} field={@form[:workout_plan_exercises]}>
                  <.exercise_form
                    form={exercise_form}
                    exercises={@exercises}
                    index={exercise_form.index}
                  />
                </.inputs_for>
              </div>

              <%= if Enum.empty?(@form[:workout_plan_exercises].value || []) do %>
                <div class="text-center py-8 text-base-content/50">
                  <.icon name="hero-queue-list" class="mx-auto h-8 w-8 mb-2" />
                  <p class="text-sm">No exercises added yet. Click "Add Exercise" to get started.</p>
                </div>
              <% end %>
            </div>
            
    <!-- Actions -->
            <div class="flex justify-end gap-3">
              <.link navigate={~p"/workout-plans"} class="btn btn-ghost">
                Cancel
              </.link>
              <.button phx-disable-with="Saving..." class="btn btn-primary">
                {@live_action == :new && "Create Plan"}
                {@live_action == :edit && "Update Plan"}
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:exercises, list_exercises(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    workout_plan = %Training.WorkoutPlan{workout_plan_exercises: []}
    changeset = Training.change_workout_plan(workout_plan)

    socket
    |> assign(:page_title, "New Workout Plan")
    |> assign(:workout_plan, workout_plan)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    workout_plan = Training.get_workout_plan!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Workout Plan")
    |> assign(:workout_plan, workout_plan)
    |> assign(:form, to_form(Training.change_workout_plan(workout_plan)))
  end

  @impl true
  def handle_event("validate", %{"workout_plan" => workout_plan_params}, socket) do
    changeset =
      socket.assigns.workout_plan
      |> Training.change_workout_plan(workout_plan_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"workout_plan" => workout_plan_params}, socket) do
    save_workout_plan(socket, socket.assigns.live_action, workout_plan_params)
  end

  @impl true
  def handle_event("add_exercise", _params, socket) do
    existing_exercises = socket.assigns.form[:workout_plan_exercises].value || []
    next_order = length(existing_exercises) + 1

    new_exercise = %{
      order: next_order,
      sets: 3,
      reps: "8-12",
      rest_seconds: 60,
      notes: ""
    }

    updated_exercises = existing_exercises ++ [new_exercise]

    changeset =
      socket.assigns.workout_plan
      |> Training.change_workout_plan(%{workout_plan_exercises: updated_exercises})

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("remove_exercise", %{"index" => index}, socket) do
    index = String.to_integer(index)
    existing_exercises = socket.assigns.form[:workout_plan_exercises].value || []
    updated_exercises = List.delete_at(existing_exercises, index)

    # Reorder the remaining exercises
    reordered_exercises =
      updated_exercises
      |> Enum.with_index()
      |> Enum.map(fn {exercise, idx} -> Map.put(exercise, :order, idx + 1) end)

    changeset =
      socket.assigns.workout_plan
      |> Training.change_workout_plan(%{workout_plan_exercises: reordered_exercises})

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("move_exercise", %{"index" => index, "direction" => direction}, socket) do
    index = String.to_integer(index)
    existing_exercises = socket.assigns.form[:workout_plan_exercises].value || []

    case direction do
      "up" when index > 0 ->
        # Swap with previous
        updated_exercises = swap_exercises(existing_exercises, index, index - 1)
        update_form(socket, updated_exercises)

      "down" when index < length(existing_exercises) - 1 ->
        # Swap with next
        updated_exercises = swap_exercises(existing_exercises, index, index + 1)
        update_form(socket, updated_exercises)

      _ ->
        {:noreply, socket}
    end
  end

  defp save_workout_plan(socket, :new, workout_plan_params) do
    case Training.create_workout_plan(socket.assigns.current_scope, workout_plan_params) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout plan created successfully")
         |> push_navigate(to: ~p"/workout-plans/#{workout_plan}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_workout_plan(socket, :edit, workout_plan_params) do
    case Training.update_workout_plan(
           socket.assigns.current_scope,
           socket.assigns.workout_plan,
           workout_plan_params
         ) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout plan updated successfully")
         |> push_navigate(to: ~p"/workout-plans/#{workout_plan}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp list_exercises(current_scope) do
    Training.list_exercises(current_scope)
  end

  defp swap_exercises(exercises, i, j) do
    exercises
    |> List.replace_at(i, Enum.at(exercises, j))
    |> List.replace_at(j, Enum.at(exercises, i))
    |> Enum.with_index()
    |> Enum.map(fn {exercise, idx} -> Map.put(exercise, :order, idx + 1) end)
  end

  defp update_form(socket, exercises) do
    changeset =
      socket.assigns.workout_plan
      |> Training.change_workout_plan(%{workout_plan_exercises: exercises})

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  attr :form, :map, required: true
  attr :exercises, :list, required: true
  attr :index, :integer, required: true

  defp exercise_form(assigns) do
    ~H"""
    <div class="flex items-start gap-4 p-4 rounded-lg border border-base-200 bg-base-50">
      <!-- Order indicator -->
      <div class="flex flex-col items-center gap-2">
        <div class="flex items-center justify-center w-8 h-8 rounded-full bg-primary text-white text-sm font-medium">
          {@form[:order].value}
        </div>
        <div class="flex flex-col gap-1">
          <button
            type="button"
            phx-click="move_exercise"
            phx-value-index={@index}
            phx-value-direction="up"
            class="p-1 rounded hover:bg-base-200 disabled:opacity-50"
            disabled={@index == 0}
          >
            <.icon name="hero-chevron-up" class="h-3 w-3" />
          </button>
          <button
            type="button"
            phx-click="move_exercise"
            phx-value-index={@index}
            phx-value-direction="down"
            class="p-1 rounded hover:bg-base-200 disabled:opacity-50"
            disabled={@index == length(@exercises) - 1}
          >
            <.icon name="hero-chevron-down" class="h-3 w-3" />
          </button>
        </div>
      </div>
      
    <!-- Exercise details -->
      <div class="flex-1 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <.input
          field={@form[:exercise_id]}
          type="select"
          label="Exercise"
          options={Enum.map(@exercises, &{&1.name, &1.id})}
          required
        />
        <.input field={@form[:sets]} type="number" label="Sets" min="1" required />
        <.input field={@form[:reps]} type="text" label="Reps" placeholder="8-12" required />
        <.input field={@form[:rest_seconds]} type="number" label="Rest (sec)" min="0" />
      </div>
      
    <!-- Notes and remove -->
      <div class="flex flex-col gap-2">
        <.input field={@form[:notes]} type="textarea" label="Notes" rows="2" class="w-48" />
        <button
          type="button"
          phx-click="remove_exercise"
          phx-value-index={@index}
          class="self-end p-2 rounded-lg text-rose-600 hover:bg-rose-50 transition"
        >
          <.icon name="hero-trash" class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end
end
