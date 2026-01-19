defmodule FittrackWeb.WorkoutSessionLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Workout history</h1>
            <p class="text-sm text-base-content/70">
              Review past sessions and jump back into the details whenever you need them.
            </p>
          </div>
          <.link
            navigate={~p"/sessions/new"}
            class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
          >
            Start a session
          </.link>
        </div>

        <div id="workout-sessions" phx-update="stream" class="space-y-4">
          <div class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100 p-6 text-center">
            <p class="text-sm font-semibold text-base-content">No sessions logged yet.</p>
            <p class="mt-1 text-sm text-base-content/70">
              Start your first workout to see it show up here.
            </p>
            <.link
              navigate={~p"/sessions/new"}
              class="mt-4 inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Start a session
            </.link>
          </div>

          <div
            :for={{id, session} <- @streams.workout_sessions}
            id={id}
            class="group rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40"
          >
            <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Session</p>
                <p class="text-lg font-semibold text-base-content">
                  {format_started_at(session.started_at)}
                </p>
                <p class="mt-1 text-sm text-base-content/70">
                  <%= if session.notes && session.notes != "" do %>
                    {session.notes}
                  <% else %>
                    No notes added.
                  <% end %>
                </p>
              </div>
              <.link
                navigate={~p"/sessions/#{session}"}
                class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition group-hover:border-primary group-hover:text-primary"
              >
                View session
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workout History")
     |> stream(:workout_sessions, Training.list_workout_sessions(socket.assigns.current_scope))}
  end

  defp format_started_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y • %H:%M")
  end
end
