defmodule FittrackWeb.LibraryLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto space-y-8">
        <!-- Header -->
        <div class="flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
          <div>
            <h1 class="text-3xl font-bold text-base-content">{@template.name}</h1>
            <p class="text-lg text-base-content/70 mt-2">
              {@template.primary_muscle} • {@template.equipment}
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span class={[
              "inline-flex items-center rounded-full px-3 py-1 text-sm font-medium",
              difficulty_badge_classes(@template.difficulty)
            ]}>
              {@template.difficulty}
            </span>
            <button
              phx-click="add_to_library"
              phx-value-template_id={@template.id}
              class="inline-flex items-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Add to My Exercises
            </button>
          </div>
        </div>

        <%= if @template.image_url do %>
          <div class="overflow-hidden rounded-2xl border border-base-200 bg-base-200 shadow-sm">
            <img
              id="exercise-template-image"
              src={@template.image_url}
              alt={"#{@template.name} exercise reference"}
              class="max-h-[28rem] w-full object-cover"
            />
          </div>
        <% end %>
        
    <!-- Exercise Details -->
        <div class="grid gap-8 md:grid-cols-2">
          <!-- Instructions -->
          <div class="space-y-6">
            <div>
              <h2 class="text-xl font-semibold text-base-content mb-4">Instructions</h2>
              <div class="prose prose-sm max-w-none">
                {render_instructions(@template)}
              </div>
            </div>
            
    <!-- Equipment Needed -->
            <div>
              <h3 class="text-lg font-semibold text-base-content mb-3">Equipment Needed</h3>
              <div class="flex items-center gap-2">
                <.icon name="hero-wrench-screwdriver" class="h-5 w-5 text-base-content/60" />
                <span class="text-base-content">{@template.equipment}</span>
              </div>
            </div>
            
    <!-- Target Muscles -->
            <div>
              <h3 class="text-lg font-semibold text-base-content mb-3">Target Muscles</h3>
              <div class="flex flex-wrap gap-2">
                <span class="inline-flex items-center rounded-full bg-primary/10 px-3 py-1 text-sm font-medium text-primary">
                  {@template.primary_muscle}
                </span>
              </div>
            </div>
          </div>
          
    <!-- Visual/Additional Info -->
          <div class="space-y-6">
            <!-- Difficulty Info -->
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6">
              <h3 class="text-lg font-semibold text-base-content mb-3">Difficulty Level</h3>
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-base-content/70">Level</span>
                  <span class="font-medium capitalize">{@template.difficulty}</span>
                </div>
                <div class="w-full bg-base-200 rounded-full h-2">
                  <div class={[
                    "h-2 rounded-full",
                    difficulty_progress_classes(@template.difficulty)
                  ]}>
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Notes -->
            <%= if @template.notes do %>
              <div class="rounded-2xl border border-base-200 bg-base-100 p-6">
                <h3 class="text-lg font-semibold text-base-content mb-3">Additional Notes</h3>
                <p class="text-base-content/80">{@template.notes}</p>
              </div>
            <% end %>
            
    <!-- Similar Exercises -->
            <div class="rounded-2xl border border-base-200 bg-base-100 p-6">
              <h3 class="text-lg font-semibold text-base-content mb-3">Similar Exercises</h3>
              <div class="space-y-2">
                <%= for similar <- @similar_exercises do %>
                  <.link
                    navigate={~p"/library/#{similar}"}
                    class="block p-3 rounded-lg border border-base-200 hover:border-primary/20 transition"
                  >
                    <div class="font-medium text-base-content">{similar.name}</div>
                    <div class="text-sm text-base-content/70">
                      {similar.primary_muscle} • {similar.equipment}
                    </div>
                  </.link>
                <% end %>
                <%= if Enum.empty?(@similar_exercises) do %>
                  <p class="text-base-content/70 text-sm">No similar exercises found.</p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Back to Library -->
        <div class="flex justify-center">
          <.link
            navigate={~p"/library"}
            class="inline-flex items-center gap-2 text-primary hover:text-primary/80 transition"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to Library
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    template = Training.list_exercise_templates() |> Enum.find(&(&1.id == String.to_integer(id)))

    if template do
      similar_exercises = find_similar_exercises(template)

      {:ok,
       socket
       |> assign(:page_title, template.name)
       |> assign(:template, template)
       |> assign(:similar_exercises, similar_exercises)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Exercise not found")
       |> push_navigate(to: ~p"/library")}
    end
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

  defp render_instructions(template) do
    # For now, provide generic instructions based on exercise type
    # In a real app, this would come from the database
    case template.primary_muscle do
      "Chest" ->
        Phoenix.HTML.raw("""
        <ol class="list-decimal list-inside space-y-2 text-base-content/80">
          <li>Lie flat on a bench with your feet planted firmly on the ground.</li>
          <li>Grip the barbell with hands slightly wider than shoulder-width.</li>
          <li>Lower the barbell to your chest with control.</li>
          <li>Press the barbell up explosively until arms are fully extended.</li>
          <li>Repeat for desired reps.</li>
        </ol>
        """)

      "Back" ->
        Phoenix.HTML.raw("""
        <ol class="list-decimal list-inside space-y-2 text-base-content/80">
          <li>Sit at the lat pulldown machine with knees secured under pads.</li>
          <li>Grip the bar with hands wider than shoulder-width.</li>
          <li>Pull the bar down to your upper chest while squeezing shoulder blades.</li>
          <li>Slowly return to starting position with control.</li>
          <li>Repeat for desired reps.</li>
        </ol>
        """)

      "Quads" ->
        Phoenix.HTML.raw("""
        <ol class="list-decimal list-inside space-y-2 text-base-content/80">
          <li>Position barbell on upper back/shoulders.</li>
          <li>Stand with feet shoulder-width apart.</li>
          <li>Lower your body by bending at the knees and hips.</li>
          <li>Descend until thighs are parallel to ground.</li>
          <li>Drive through heels to return to standing position.</li>
        </ol>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="text-base-content/70 italic">
          Detailed instructions for this exercise will be added soon.
        </div>
        """)
    end
  end

  defp find_similar_exercises(template) do
    Training.list_exercise_templates()
    |> Enum.filter(&(&1.id != template.id && &1.primary_muscle == template.primary_muscle))
    |> Enum.take(3)
  end

  defp difficulty_badge_classes("beginner"), do: "bg-green-100 text-green-800"
  defp difficulty_badge_classes("intermediate"), do: "bg-yellow-100 text-yellow-800"
  defp difficulty_badge_classes("advanced"), do: "bg-red-100 text-red-800"
  defp difficulty_badge_classes(_), do: "bg-gray-100 text-gray-800"

  defp difficulty_progress_classes("beginner"), do: "bg-green-500 w-1/3"
  defp difficulty_progress_classes("intermediate"), do: "bg-yellow-500 w-2/3"
  defp difficulty_progress_classes("advanced"), do: "bg-red-500 w-full"
  defp difficulty_progress_classes(_), do: "bg-gray-500 w-1/2"
end
