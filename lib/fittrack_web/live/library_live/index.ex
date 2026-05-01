defmodule FittrackWeb.LibraryLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold text-base-content">Exercise Library</h1>
            <p class="text-sm text-base-content/70">
              Explore the full exercise catalog and add movements to your exercise list.
            </p>
          </div>
        </div>
        
    <!-- Filters -->
        <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
          <.form for={@form} id="library-filters-form" phx-change="filter" phx-debounce="300">
            <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <.input
                field={@form[:search]}
                type="search"
                label="Search exercises"
                placeholder="Search by name, muscle, or equipment"
              />
              <.input
                field={@form[:muscle_group]}
                type="select"
                label="Muscle Group"
                options={[
                  "",
                  "Chest",
                  "Back",
                  "Shoulders",
                  "Biceps",
                  "Triceps",
                  "Quads",
                  "Hamstrings",
                  "Calves",
                  "Core",
                  "Posterior Chain"
                ]}
              />
              <.input
                field={@form[:equipment]}
                type="select"
                label="Equipment"
                options={["", "Barbell", "Dumbbells", "Cable", "Bodyweight", "Machine", "Kettlebell"]}
              />
              <.input
                field={@form[:difficulty]}
                type="select"
                label="Difficulty"
                options={["", "beginner", "intermediate", "advanced"]}
              />
            </div>
          </.form>
        </div>
        
    <!-- Exercise Grid -->
        <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          <%= for template <- @templates do %>
            <.exercise_card template={template} />
          <% end %>
        </div>

        <%= if Enum.empty?(@templates) do %>
          <div class="text-center py-12">
            <div class="text-base-content/50">
              <.icon name="hero-magnifying-glass" class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-base-content">No exercises found</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Try adjusting your filters or search terms.
              </p>
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
     |> assign(:page_title, "Exercise Library")
     |> assign(
       :form,
       to_form(%{"search" => "", "muscle_group" => "", "equipment" => "", "difficulty" => ""},
         as: :filters
       )
     )
     |> assign(:templates, list_templates(%{}))}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    filters =
      Map.new(filters, fn {k, v} -> {String.to_atom(k), if(v == "", do: nil, else: v)} end)

    {:noreply,
     socket
     |> assign(:form, to_form(filters, as: :filters))
     |> assign(:templates, list_templates(filters))}
  end

  @impl true
  def handle_event("add_to_library", %{"template_id" => template_id}, socket) do
    case Training.add_template_to_user(
           socket.assigns.current_scope,
           String.to_integer(template_id)
         ) do
      {:ok, exercise} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{exercise.name} added to your exercises")
         |> push_navigate(to: ~p"/exercises/#{exercise}")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Exercise template not found")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp list_templates(filters) do
    Training.list_exercise_templates(filters)
  end

  attr :template, :map, required: true

  defp exercise_card(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-2xl border border-base-200 bg-base-100 shadow-sm transition hover:border-primary/20 hover:shadow-md">
      <%= if @template.image_url do %>
        <div class="aspect-[4/3] bg-base-200">
          <img
            src={~p"/exercise-template-images/#{@template.id}"}
            alt={"#{@template.name} exercise reference"}
            class="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
            loading="lazy"
          />
        </div>
      <% end %>
      <div class="p-6">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <h3 class="font-semibold text-base-content group-hover:text-primary transition">
              {@template.name}
            </h3>
            <p class="text-sm text-base-content/70 mt-1">
              {@template.primary_muscle}
            </p>
          </div>
          <div class="flex flex-col items-end gap-2">
            <span class={[
              "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium",
              difficulty_badge_classes(@template.difficulty)
            ]}>
              {@template.difficulty}
            </span>
          </div>
        </div>

        <div class="mt-4 flex items-center justify-between">
          <div class="flex items-center gap-2 text-sm text-base-content/60">
            <.icon name="hero-wrench-screwdriver" class="h-4 w-4" />
            {@template.equipment}
          </div>
          <button
            phx-click="add_to_library"
            phx-value-template_id={@template.id}
            class="inline-flex items-center gap-2 rounded-full bg-primary px-3 py-1.5 text-xs font-medium text-white shadow-sm transition hover:bg-primary/90"
          >
            <.icon name="hero-plus" class="h-3 w-3" /> Add to My Exercises
          </button>
        </div>

        <%= if @template.notes do %>
          <div class="mt-4 rounded-lg bg-base-200/50 p-3">
            <p class="text-sm text-base-content/80">{@template.notes}</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp difficulty_badge_classes("beginner"), do: "bg-green-100 text-green-800"
  defp difficulty_badge_classes("intermediate"), do: "bg-yellow-100 text-yellow-800"
  defp difficulty_badge_classes("advanced"), do: "bg-red-100 text-red-800"
  defp difficulty_badge_classes(_), do: "bg-gray-100 text-gray-800"
end
