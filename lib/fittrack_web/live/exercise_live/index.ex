defmodule FittrackWeb.ExerciseLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Exercises</h1>
            <p class="text-sm text-base-content/70">
              Keep your personal exercise list organized for workout planning and logging.
            </p>
          </div>
          <div class="flex gap-3">
            <.link
              navigate={~p"/exercises"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-book-open" class="mr-2 size-4" /> Browse Library
            </.link>
            <.link
              navigate={~p"/my-exercises/new"}
              class="inline-flex items-center justify-center rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="mr-2 size-4" /> New exercise
            </.link>
          </div>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm">
          <.form for={@form} id="exercise-search-form" phx-change="search" phx-debounce="300">
            <div class="grid gap-4 md:grid-cols-[1fr_auto] md:items-end">
              <.input
                field={@form[:search]}
                type="search"
                label="Search exercises"
                placeholder="Search by name, muscle group, or equipment"
              />
              <.link
                navigate={~p"/my-exercises/new"}
                class="hidden md:inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              >
                Add new
              </.link>
            </div>
          </.form>
        </div>

        <.table
          id="exercises"
          rows={@streams.exercises}
          row_click={fn {_id, exercise} -> JS.navigate(~p"/my-exercises/#{exercise}") end}
        >
          <:col :let={{_id, exercise}} label="">
            <.exercise_thumbnail exercise={exercise} />
          </:col>
          <:col :let={{_id, exercise}} label="Name">{exercise.name}</:col>
          <:col :let={{_id, exercise}} label="Primary muscle">{exercise.primary_muscle}</:col>
          <:col :let={{_id, exercise}} label="Equipment">{exercise.equipment}</:col>
          <:col :let={{_id, exercise}} label="Notes">{exercise.notes}</:col>
          <:action :let={{_id, exercise}}>
            <div class="sr-only">
              <.link navigate={~p"/my-exercises/#{exercise}"}>Show</.link>
            </div>
            <.link navigate={~p"/my-exercises/#{exercise}/edit"} class="text-primary hover:underline">
              Edit
            </.link>
          </:action>
          <:action :let={{id, exercise}}>
            <.link
              phx-click={JS.push("delete", value: %{id: exercise.id}) |> hide("##{id}")}
              data-confirm="Are you sure?"
              class="text-rose-500 hover:underline"
            >
              Delete
            </.link>
          </:action>
        </.table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Exercises")
     |> assign(:form, to_form(%{"search" => ""}, as: :filters))
     |> stream(:exercises, list_exercises(socket.assigns.current_scope, ""))}
  end

  @impl true
  def handle_event("search", %{"filters" => %{"search" => search}}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(%{"search" => search}, as: :filters))
     |> stream(:exercises, list_exercises(socket.assigns.current_scope, search), reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    exercise = Training.get_exercise!(socket.assigns.current_scope, id)
    {:ok, _} = Training.delete_exercise(socket.assigns.current_scope, exercise)

    {:noreply, stream_delete(socket, :exercises, exercise)}
  end

  defp list_exercises(current_scope, search) do
    Training.list_exercises(current_scope, %{search: search, preload_source_template: true})
  end

  attr :exercise, :map, required: true

  defp exercise_thumbnail(assigns) do
    ~H"""
    <%= if exercise_image_url(@exercise) do %>
      <div class="h-12 w-12 overflow-hidden rounded-lg bg-base-200">
        <img
          src={exercise_image_url(@exercise)}
          alt={"#{@exercise.name} exercise reference"}
          class="h-full w-full object-cover"
          loading="lazy"
        />
      </div>
    <% else %>
      <span class="block h-12 w-12" aria-hidden="true"></span>
    <% end %>
    """
  end

  defp exercise_image_url(%{source_template: %{id: id, image_url: image_url}})
       when is_binary(image_url) do
    ~p"/exercise-template-images/#{id}"
  end

  defp exercise_image_url(_exercise), do: nil
end
