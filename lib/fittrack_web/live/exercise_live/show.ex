defmodule FittrackWeb.ExerciseLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Exercise {@exercise.name}
        <:subtitle>This is a exercise record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/my-exercises"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/my-exercises/#{@exercise}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit exercise
          </.button>
        </:actions>
      </.header>

      <%= if media_url = exercise_media_url(@exercise) do %>
        <div class="mb-6 overflow-hidden rounded-2xl border border-base-200 bg-base-200 shadow-sm">
          <img
            id="exercise-image"
            src={media_url}
            alt={"#{@exercise.name} exercise reference"}
            class="max-h-[28rem] w-full object-cover"
          />
        </div>
      <% end %>

      <.list>
        <:item title="Name">{@exercise.name}</:item>
        <:item title="Primary muscle">{@exercise.primary_muscle}</:item>
        <:item title="Equipment">{@exercise.equipment}</:item>
        <:item title="Notes">{@exercise.notes}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Exercise")
     |> assign(
       :exercise,
       Training.get_exercise!(socket.assigns.current_scope, id, preload_source_template: true)
     )}
  end
end
