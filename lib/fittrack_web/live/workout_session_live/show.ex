defmodule FittrackWeb.WorkoutSessionLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training
  alias Fittrack.Training.WorkoutSet

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Workout session</p>
            <h1 class="mt-2 text-2xl font-semibold text-base-content">
              {format_started_at(@workout_session.started_at)}
            </h1>
            <p class="mt-1 text-sm text-base-content/70">
              <%= if @workout_session.notes && @workout_session.notes != "" do %>
                {@workout_session.notes}
              <% else %>
                No notes added yet.
              <% end %>
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/sessions"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Back to history
            </.link>
            <.link
              navigate={~p"/exercises"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Manage exercises
            </.link>
          </div>
        </div>

        <section class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 class="text-lg font-semibold text-base-content">Log a set</h2>
              <p class="text-sm text-base-content/70">
                Add sets to track the work you performed in this session.
              </p>
            </div>
            <%= if @exercise_options == [] do %>
              <.link
                navigate={~p"/exercises/new"}
                class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              >
                Create an exercise
              </.link>
            <% end %>
          </div>

          <%= if @exercise_options == [] do %>
            <div class="mt-6 rounded-2xl border border-dashed border-base-300 bg-base-100/60 p-6 text-sm text-base-content/70">
              You need at least one exercise before you can log sets. Create one to keep going.
            </div>
          <% else %>
            <.form for={@form} id="workout-set-form" phx-change="validate" phx-submit="save">
              <div class="mt-6 grid gap-4 md:grid-cols-2">
                <.input
                  field={@form[:exercise_id]}
                  type="select"
                  label="Exercise"
                  options={@exercise_options}
                  prompt="Select exercise"
                  required
                />
                <.input
                  field={@form[:kind]}
                  type="select"
                  label="Set type"
                  options={@kind_options}
                />
                <.input
                  field={@form[:weight]}
                  type="number"
                  step="0.5"
                  label="Weight"
                  required
                  placeholder="e.g. 135"
                />
                <.input
                  field={@form[:reps]}
                  type="number"
                  label="Reps"
                  required
                  placeholder="e.g. 8"
                />
                <.input
                  field={@form[:rpe]}
                  type="number"
                  step="0.5"
                  label="RPE (optional)"
                  placeholder="e.g. 7.5"
                />
                <.input
                  field={@form[:rest_seconds]}
                  type="number"
                  label="Rest (seconds, optional)"
                  placeholder="e.g. 90"
                />
                <div class="md:col-span-2">
                  <.input
                    field={@form[:notes]}
                    type="textarea"
                    label="Set notes (optional)"
                    placeholder="Add any notes about tempo, cues, or setup"
                  />
                </div>
              </div>

              <div class="mt-6">
                <button
                  type="submit"
                  phx-disable-with="Adding..."
                  class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90 disabled:opacity-70"
                >
                  Add set
                </button>
              </div>
            </.form>
          <% end %>
        </section>

        <section>
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-base-content">Session sets</h2>
            <span class="text-xs uppercase tracking-[0.2em] text-base-content/50">
              {format_started_at(@workout_session.started_at)}
            </span>
          </div>

          <div
            id="workout-sets"
            phx-update="stream"
            class="mt-4 grid gap-4 sm:grid-cols-2"
          >
            <div class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100/60 p-6 text-center text-sm text-base-content/70">
              No sets yet — add your first set above.
            </div>
            <div
              :for={{id, workout_set} <- @streams.workout_sets}
              id={id}
              class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm"
            >
              <div class="flex items-center justify-between">
                <p class="text-sm font-semibold text-base-content">
                  {workout_set.exercise.name}
                </p>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/40">
                  {format_weight(workout_set.weight)}
                </p>
              </div>
              <div class="mt-2 flex flex-wrap items-center gap-2">
                <span class="rounded-full border border-base-200 bg-base-100 px-2.5 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-base-content/70">
                  {WorkoutSet.kind_label(workout_set.kind)}
                </span>
              </div>
              <div class="mt-3 space-y-2 text-sm text-base-content/70">
                <p>
                  <span class="font-semibold text-base-content">Reps:</span> {workout_set.reps}
                </p>
                <p :if={workout_set.rpe}>
                  <span class="font-semibold text-base-content">RPE:</span> {workout_set.rpe}
                </p>
                <p :if={workout_set.rest_seconds}>
                  <span class="font-semibold text-base-content">Rest:</span>
                  {workout_set.rest_seconds}s
                </p>
                <p :if={workout_set.notes && workout_set.notes != ""}>
                  <span class="font-semibold text-base-content">Notes:</span>
                  {workout_set.notes}
                </p>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    workout_session = Training.get_workout_session!(socket.assigns.current_scope, id)
    exercise_options = exercise_options(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Workout Session")
     |> assign(:workout_session, workout_session)
     |> assign(:exercise_options, exercise_options)
     |> assign(:form, to_form(Training.change_workout_set(%WorkoutSet{})))
     |> assign(:kind_options, WorkoutSet.kind_options())
     |> stream(:workout_sets, workout_session.workout_sets)}
  end

  @impl true
  def handle_event("validate", %{"workout_set" => params}, socket) do
    changeset = Training.change_workout_set(%WorkoutSet{}, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"workout_set" => params}, socket) do
    case Training.create_workout_set(
           socket.assigns.current_scope,
           socket.assigns.workout_session,
           params
         ) do
      {:ok, workout_set} ->
        {:noreply,
         socket
         |> stream_insert(:workout_sets, workout_set, at: -1)
         |> assign(:form, to_form(Training.change_workout_set(%WorkoutSet{})))}

      {:error, :invalid_exercise} ->
        {:noreply, put_flash(socket, :error, "Select a valid exercise to continue.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to add sets here.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  defp exercise_options(current_scope) do
    current_scope
    |> Training.list_exercises()
    |> Enum.map(fn exercise -> {exercise.name, exercise.id} end)
  end

  defp format_started_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y • %H:%M")
  end

  defp format_weight(weight) do
    weight
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end
end
