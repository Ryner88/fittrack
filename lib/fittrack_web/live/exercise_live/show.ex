defmodule FittrackWeb.ExerciseLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Exercise {@exercise.id}
        <:subtitle>This is a exercise record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/exercises"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/exercises/#{@exercise}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit exercise
          </.button>
        </:actions>
      </.header>

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
     |> assign(:exercise, Training.get_exercise!(id))}
  end
end
