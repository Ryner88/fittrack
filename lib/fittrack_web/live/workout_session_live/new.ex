defmodule FittrackWeb.WorkoutSessionLive.New do
  use FittrackWeb, :live_view

  alias Fittrack.Training
  alias Fittrack.Training.WorkoutSession

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">New session</p>
          <h1 class="mt-2 text-2xl font-semibold text-base-content">Start a workout session</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Capture the date and any quick notes before you begin logging sets.
          </p>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <.form for={@form} id="workout-session-form" phx-change="validate" phx-submit="save">
            <.input
              field={@form[:started_at]}
              type="datetime-local"
              label="Session date & time"
              required
            />
            <.input field={@form[:notes]} type="textarea" label="Notes (optional)" />

            <div class="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
              <button
                type="submit"
                class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
              >
                Start session
              </button>
              <.link
                navigate={~p"/sessions"}
                class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              >
                Cancel
              </.link>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    session = %WorkoutSession{started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}

    {:ok,
     socket
     |> assign(:page_title, "Start Workout Session")
     |> assign(:workout_session, session)
     |> assign(:form, to_form(Training.change_workout_session(session)))}
  end

  @impl true
  def handle_event("validate", %{"workout_session" => params}, socket) do
    changeset = Training.change_workout_session(socket.assigns.workout_session, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"workout_session" => params}, socket) do
    case Training.create_workout_session(socket.assigns.current_scope, params) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout session started")
         |> push_navigate(to: ~p"/sessions/#{session}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
