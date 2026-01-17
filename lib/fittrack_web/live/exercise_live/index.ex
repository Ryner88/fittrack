defmodule FittrackWeb.ExerciseLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Exercises
        <:actions>
          <.button variant="primary" navigate={~p"/exercises/new"}>
            <.icon name="hero-plus" /> New Exercise
          </.button>
        </:actions>
      </.header>

      <.table
        id="exercises"
        rows={@streams.exercises}
        row_click={fn {_id, exercise} -> JS.navigate(~p"/exercises/#{exercise}") end}
      >
        <:col :let={{_id, exercise}} label="Name">{exercise.name}</:col>
        <:col :let={{_id, exercise}} label="Primary muscle">{exercise.primary_muscle}</:col>
        <:col :let={{_id, exercise}} label="Equipment">{exercise.equipment}</:col>
        <:col :let={{_id, exercise}} label="Notes">{exercise.notes}</:col>
        <:action :let={{_id, exercise}}>
          <div class="sr-only">
            <.link navigate={~p"/exercises/#{exercise}"}>Show</.link>
          </div>
          <.link navigate={~p"/exercises/#{exercise}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, exercise}}>
          <.link
            phx-click={JS.push("delete", value: %{id: exercise.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Exercises")
     |> stream(:exercises, list_exercises())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    exercise = Training.get_exercise!(id)
    {:ok, _} = Training.delete_exercise(exercise)

    {:noreply, stream_delete(socket, :exercises, exercise)}
  end

  defp list_exercises() do
    Training.list_exercises()
  end
end
