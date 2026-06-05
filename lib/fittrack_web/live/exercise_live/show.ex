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

      <%= if exercise_image_url(@exercise) do %>
        <div class="mb-6 overflow-hidden rounded-2xl border border-base-200 bg-base-200 shadow-sm">
          <img
            id="exercise-image"
            src={exercise_image_url(@exercise)}
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

  defp exercise_image_url(%{source_template: %{media: media}}) when is_list(media) do
    media
    |> Enum.filter(&(&1.cache_status == "cached" and &1.kind in ["image", "thumbnail"]))
    |> Enum.sort_by(fn item -> {not item.is_primary, item.display_order || 0, item.id || 0} end)
    |> List.first()
    |> case do
      nil -> nil
      item -> ~p"/exercise-media/#{item.id}"
    end
  end

  defp exercise_image_url(_exercise), do: nil
end
