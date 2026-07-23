defmodule FittrackWeb.WorkoutLive.Show do
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
            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Workout</p>
            <h1 class="mt-2 text-2xl font-semibold text-base-content">
              {format_started_at(@workout.started_at)}
            </h1>
            <p class="mt-1 text-sm text-base-content/70">
              <%= if @workout.notes && @workout.notes != "" do %>
                {@workout.notes}
              <% else %>
                No notes added yet.
              <% end %>
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/workouts"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Back to history
            </.link>
            <.link
              navigate={~p"/my-exercises"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Manage exercises
            </.link>
          </div>
        </div>

        <section class="grid gap-4 md:grid-cols-4">
          <div
            id="workout-source-summary"
            class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm md:col-span-2"
          >
            <p class="text-xs uppercase tracking-[0.18em] text-base-content/50">Workout source</p>
            <h2 class="mt-2 text-lg font-semibold text-base-content">
              {workout_source_label(@workout)}
            </h2>
            <p class="mt-1 text-sm text-base-content/70">
              Plan targets stay with the template. Log only the sets, reps, and weight you actually perform here.
            </p>
          </div>
          <div
            id="performed-set-summary"
            class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm"
          >
            <p class="text-xs uppercase tracking-[0.18em] text-base-content/50">Performed sets</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">{@performed_summary.sets}</p>
          </div>
          <div
            id="performed-volume-summary"
            class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm"
          >
            <p class="text-xs uppercase tracking-[0.18em] text-base-content/50">Performed volume</p>
            <p class="mt-2 text-3xl font-semibold text-base-content">
              {@performed_summary.volume} lbs
            </p>
          </div>
        </section>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <div class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-lg font-semibold text-base-content">Log a set</h2>
                <p class="text-sm text-base-content/70">
                  Add sets to track the work you performed in this session.
                </p>
              </div>
              <%= if @exercise_options == [] do %>
                <.link
                  navigate={~p"/my-exercises/new"}
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
                  <div
                    id="workout-form-reference"
                    class="rounded-xl border border-base-200 bg-base-50 px-4 py-3 text-sm md:col-span-2"
                  >
                    <%= if reference = exercise_media_reference(@selected_exercise) do %>
                      <div class="flex flex-wrap items-center justify-between gap-2">
                        <span class="text-xs font-semibold uppercase tracking-[0.16em] text-base-content/50">
                          Form reference
                        </span>
                        <.form_reference_link reference={reference} />
                      </div>
                    <% else %>
                      <p class="text-xs font-semibold uppercase tracking-[0.16em] text-base-content/45">
                        No form reference available
                      </p>
                    <% end %>
                  </div>
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
                    label="Performed weight"
                    required
                    placeholder="e.g. 135"
                  />
                  <.input
                    field={@form[:reps]}
                    type="number"
                    label="Performed reps"
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
                  <div class="grid gap-4 sm:grid-cols-2 md:col-span-2">
                    <.input
                      field={@form[:rest_minutes]}
                      type="number"
                      label="Rest minutes (optional)"
                      placeholder="e.g. 1"
                    />
                    <.input
                      field={@form[:rest_seconds_input]}
                      type="number"
                      label="Rest seconds (optional)"
                      placeholder="e.g. 30"
                    />
                  </div>
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

              <section
                :if={@selected_exercise && @substitution_suggestions != []}
                id="substitution-suggestions"
                class="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-4"
              >
                <div>
                  <p class="text-sm font-semibold text-amber-900">
                    Can't do {@selected_exercise.name}?
                  </p>
                  <p class="mt-1 text-xs text-amber-800/80">
                    Try a nearby substitute and keep the workout moving.
                  </p>
                </div>
                <div class="mt-3 grid gap-2">
                  <button
                    :for={suggestion <- @substitution_suggestions}
                    id={"substitute-template-#{suggestion.substitute_exercise_template.id}"}
                    type="button"
                    phx-click="prefill_from_library"
                    phx-value-template_id={suggestion.substitute_exercise_template.id}
                    class="flex items-center justify-between gap-3 rounded-xl border border-amber-200 bg-white px-3 py-2 text-left text-sm text-base-content transition hover:border-primary hover:text-primary"
                  >
                    <span class="min-w-0">
                      <span class="block font-semibold">
                        {suggestion.substitute_exercise_template.name}
                      </span>
                      <span class="mt-1 block text-xs text-base-content/60">
                        {substitution_meta(suggestion)}
                      </span>
                    </span>
                    <.icon name="hero-arrow-right" class="h-4 w-4" />
                  </button>
                </div>
              </section>

              <div
                id="rest-timer"
                phx-hook="RestTimer"
                class="mt-6 rounded-2xl border border-base-200 bg-base-50 p-4"
              >
                <h3 class="text-sm font-semibold text-base-content">Rest Timer & Stopwatch</h3>
                <div class="mt-2 flex items-center justify-between gap-2">
                  <div class="text-2xl font-mono text-base-content" data-timer-display>01:00</div>
                  <div class="flex gap-2">
                    <button type="button" data-start-rest class="btn btn-sm btn-primary">
                      Start Rest
                    </button>
                    <button type="button" data-stop-rest class="btn btn-sm btn-outline">Stop</button>
                  </div>
                </div>
                <div class="mt-3 grid grid-cols-2 gap-2">
                  <input
                    data-rest-input
                    type="number"
                    min="1"
                    value="60"
                    class="w-full rounded-lg border border-base-300 px-3 py-2"
                  />
                  <span class="text-xs text-base-content/70">Rest seconds</span>
                </div>

                <div class="mt-4 border-t border-base-200 pt-3">
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-semibold">Stopwatch</span>
                    <span data-stopwatch-display class="font-mono">00:00</span>
                  </div>
                  <div class="mt-2 flex gap-2">
                    <button type="button" data-toggle-stopwatch class="btn btn-sm btn-primary">
                      Start Stopwatch
                    </button>
                    <button type="button" data-reset-stopwatch class="btn btn-sm btn-outline">
                      Reset
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <aside class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div>
              <h2 class="text-lg font-semibold text-base-content">Library</h2>
              <p class="text-sm text-base-content/70">
                Add a shared template to your personal exercise list in one tap.
              </p>
            </div>

            <div
              :if={@recent_exercises != [] || @popular_exercises != []}
              id="workout-exercise-shortcuts"
              class="mt-5 grid gap-4"
            >
              <.shortcut_group
                id_prefix="recent"
                title="Recently used"
                exercises={@recent_exercises}
              />
              <.shortcut_group
                id_prefix="popular"
                title="Most logged"
                exercises={@popular_exercises}
              />
            </div>

            <div class="mt-4 space-y-4">
              <.form
                for={@library_form}
                id="library-search-form"
                phx-change="library_search"
                phx-debounce="300"
              >
                <.input
                  field={@library_form[:search]}
                  type="search"
                  label="Search templates"
                  placeholder="Search by name, muscle, or equipment"
                />
              </.form>

              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  phx-click="library_filter"
                  phx-value-filter="all"
                  class={[
                    "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] transition",
                    @library_filter == "all" &&
                      "border-primary bg-primary text-white shadow-sm shadow-primary/30",
                    @library_filter != "all" &&
                      "border-base-200 bg-base-100 text-base-content/70 hover:border-primary/60 hover:text-primary"
                  ]}
                >
                  All templates
                </button>
                <button
                  type="button"
                  phx-click="library_filter"
                  phx-value-filter="favorites"
                  class={[
                    "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] transition",
                    @library_filter == "favorites" &&
                      "border-primary bg-primary text-white shadow-sm shadow-primary/30",
                    @library_filter != "favorites" &&
                      "border-base-200 bg-base-100 text-base-content/70 hover:border-primary/60 hover:text-primary"
                  ]}
                >
                  Favorites
                </button>
                <button
                  type="button"
                  phx-click="library_filter"
                  phx-value-filter="recent"
                  class={[
                    "rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] transition",
                    @library_filter == "recent" &&
                      "border-primary bg-primary text-white shadow-sm shadow-primary/30",
                    @library_filter != "recent" &&
                      "border-base-200 bg-base-100 text-base-content/70 hover:border-primary/60 hover:text-primary"
                  ]}
                >
                  Recent
                </button>
              </div>
            </div>

            <div id="library-templates" class="mt-4 space-y-3">
              <%= if @filtered_library == [] do %>
                <div class="rounded-2xl border border-dashed border-base-300 bg-base-100/60 p-4 text-sm text-base-content/70">
                  No templates match your search yet. Try a different keyword.
                </div>
              <% else %>
                <div
                  :for={template <- @filtered_library}
                  class="rounded-2xl border border-base-200 bg-base-100 p-4 transition hover:border-primary/40 hover:shadow-sm"
                >
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex min-w-0 items-start gap-3">
                      <.media_thumb
                        id={"library-template-media-#{template.id}"}
                        src={exercise_media_url(template)}
                        name={template.name}
                      />
                      <div class="min-w-0">
                        <p class="truncate text-sm font-semibold text-base-content">
                          {template.name}
                        </p>
                        <p class="mt-1 text-xs text-base-content/60">
                          {format_template_meta(template)}
                        </p>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="prefill_from_library"
                      phx-value-template_id={template.id}
                      class="inline-flex items-center justify-center rounded-full border border-primary/30 bg-primary/10 px-3 py-1.5 text-xs font-semibold text-primary transition hover:-translate-y-0.5 hover:border-primary hover:bg-primary hover:text-white"
                    >
                      Add
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </aside>
        </section>

        <section>
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-base-content">Workout sets</h2>
            <span class="text-xs uppercase tracking-[0.2em] text-base-content/50">
              {format_started_at(@workout.started_at)}
            </span>
          </div>

          <div
            id="workout-sets"
            phx-update="stream"
            class="mt-4 grid gap-4 sm:grid-cols-2"
          >
            <div
              id="workout-sets-empty"
              class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100/60 p-6 text-center text-sm text-base-content/70"
            >
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
                  {format_rest_seconds(workout_set.rest_seconds)}
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
  def mount(%{"id" => id} = params, _session, socket) do
    workout = Training.get_workout!(socket.assigns.current_scope, id)
    exercise_options = exercise_options(socket.assigns.current_scope)
    templates = Training.list_exercise_templates(%{})
    form = workout_set_form(socket.assigns.current_scope, params)
    selected_exercise = selected_exercise(socket.assigns.current_scope, params)

    {:ok,
     socket
     |> assign(:page_title, "Workout")
     |> assign(:workout, workout)
     |> assign(:performed_summary, performed_summary(workout.workout_sets))
     |> assign(:exercise_options, exercise_options)
     |> assign(:form, form)
     |> assign(:selected_exercise, selected_exercise)
     |> assign(
       :substitution_suggestions,
       substitution_suggestions(socket.assigns.current_scope, selected_exercise)
     )
     |> assign(
       :recent_exercises,
       Training.list_recent_exercises(socket.assigns.current_scope, limit: 5)
     )
     |> assign(
       :popular_exercises,
       Training.list_popular_exercises(socket.assigns.current_scope, limit: 5)
     )
     |> assign(:kind_options, WorkoutSet.kind_options())
     |> assign(:library_templates, templates)
     |> assign(:filtered_library, templates)
     |> assign(:library_filter, "all")
     |> assign(:library_search, "")
     |> assign(:library_form, to_form(%{"search" => ""}, as: :library))
     |> stream(:workout_sets, workout.workout_sets)}
  end

  @impl true
  def handle_event("library_search", %{"library" => %{"search" => search}}, socket) do
    filtered =
      filter_library_templates(
        socket.assigns.library_templates,
        search,
        socket.assigns.library_filter
      )

    {:noreply,
     socket
     |> assign(:library_search, search)
     |> assign(:library_form, to_form(%{"search" => search}, as: :library))
     |> assign(:filtered_library, filtered)}
  end

  def handle_event("library_filter", %{"filter" => filter}, socket) do
    filtered =
      filter_library_templates(
        socket.assigns.library_templates,
        socket.assigns.library_search,
        filter
      )

    {:noreply,
     socket
     |> assign(:library_filter, filter)
     |> assign(:filtered_library, filtered)}
  end

  def handle_event("prefill_from_library", %{"template_id" => template_id}, socket) do
    case Training.add_template_to_user(socket.assigns.current_scope, template_id) do
      {:ok, exercise} ->
        exercise_options = exercise_options(socket.assigns.current_scope)
        changeset = Training.change_workout_set(%WorkoutSet{}, %{"exercise_id" => exercise.id})

        {:noreply,
         socket
         |> assign(:exercise_options, exercise_options)
         |> assign(:selected_exercise, exercise)
         |> assign(
           :substitution_suggestions,
           substitution_suggestions(socket.assigns.current_scope, exercise)
         )
         |> assign(:form, to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That template is no longer available.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to add this template.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to add the template right now.")}
    end
  end

  def handle_event("prefill_exercise", %{"exercise_id" => exercise_id}, socket) do
    case Training.get_exercise(socket.assigns.current_scope, exercise_id,
           preload_source_template: true
         ) do
      nil ->
        {:noreply, put_flash(socket, :error, "That exercise is no longer available.")}

      exercise ->
        changeset = Training.change_workout_set(%WorkoutSet{}, %{"exercise_id" => exercise.id})

        {:noreply,
         socket
         |> assign(:selected_exercise, exercise)
         |> assign(
           :substitution_suggestions,
           substitution_suggestions(socket.assigns.current_scope, exercise)
         )
         |> assign(:form, to_form(changeset))}
    end
  end

  def handle_event("validate", %{"workout_set" => params}, socket) do
    changeset = Training.change_workout_set(%WorkoutSet{}, params)
    selected_exercise = selected_exercise(socket.assigns.current_scope, params)

    {:noreply,
     socket
     |> assign(:selected_exercise, selected_exercise)
     |> assign(
       :substitution_suggestions,
       substitution_suggestions(socket.assigns.current_scope, selected_exercise)
     )
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"workout_set" => params}, socket) do
    case Training.create_workout_set(
           socket.assigns.current_scope,
           socket.assigns.workout,
           params
         ) do
      {:ok, workout_set} ->
        workout = Training.get_workout!(socket.assigns.current_scope, socket.assigns.workout.id)

        {:noreply,
         socket
         |> stream_insert(:workout_sets, workout_set, at: -1)
         |> assign(:workout, workout)
         |> assign(:performed_summary, performed_summary(workout.workout_sets))
         |> assign(
           :recent_exercises,
           Training.list_recent_exercises(socket.assigns.current_scope, limit: 5)
         )
         |> assign(
           :popular_exercises,
           Training.list_popular_exercises(socket.assigns.current_scope, limit: 5)
         )
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

  defp workout_set_form(current_scope, %{"exercise_id" => exercise_id}) do
    attrs =
      case Training.get_exercise(current_scope, exercise_id, preload_source_template: true) do
        nil -> %{}
        exercise -> %{"exercise_id" => exercise.id}
      end

    %WorkoutSet{}
    |> Training.change_workout_set(attrs)
    |> to_form()
  end

  defp workout_set_form(_current_scope, _params) do
    to_form(Training.change_workout_set(%WorkoutSet{}))
  end

  defp selected_exercise(_current_scope, %{"exercise_id" => ""}), do: nil

  defp selected_exercise(current_scope, %{"exercise_id" => exercise_id}) do
    Training.get_exercise(current_scope, exercise_id, preload_source_template: true)
  end

  defp selected_exercise(_current_scope, _params), do: nil

  defp substitution_suggestions(_current_scope, nil), do: []

  defp substitution_suggestions(current_scope, exercise) do
    Training.list_substitution_suggestions_for_exercise(current_scope, exercise.id, limit: 4)
  end

  defp substitution_meta(suggestion) do
    [
      metadata_score("Match", suggestion.similarity_score),
      metadata_score("Reason", suggestion.reason_quality),
      difficulty_delta_label(suggestion.difficulty_delta),
      equipment_requirement_label(suggestion.equipment_requirements)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp metadata_score(_label, nil), do: nil
  defp metadata_score(label, score), do: "#{label} #{score}/100"

  defp difficulty_delta_label(nil), do: nil
  defp difficulty_delta_label(0), do: "Same difficulty"

  defp difficulty_delta_label(delta) when delta > 0, do: "+#{delta} difficulty"
  defp difficulty_delta_label(delta), do: "#{delta} difficulty"

  defp equipment_requirement_label([]), do: nil
  defp equipment_requirement_label(nil), do: nil

  defp equipment_requirement_label(equipment) do
    "Needs #{Enum.join(equipment, ", ")}"
  end

  attr :title, :string, required: true
  attr :exercises, :list, required: true
  attr :id_prefix, :string, required: true

  defp shortcut_group(assigns) do
    ~H"""
    <section :if={@exercises != []} class="rounded-2xl border border-base-200 bg-base-100 p-4">
      <h3 class="text-sm font-semibold text-base-content">{@title}</h3>
      <div class="mt-3 grid gap-2">
        <button
          :for={exercise <- @exercises}
          id={"#{@id_prefix}-shortcut-exercise-#{exercise.id}"}
          type="button"
          phx-click="prefill_exercise"
          phx-value-exercise_id={exercise.id}
          class="flex items-center justify-between rounded-xl border border-base-200 px-3 py-2 text-left text-sm transition hover:border-primary/40 hover:text-primary"
        >
          <span class="flex min-w-0 items-center gap-3">
            <.media_thumb
              id={"#{@id_prefix}-shortcut-media-#{exercise.id}"}
              src={exercise_media_url(exercise)}
              name={exercise.name}
            />
            <span class="min-w-0">
              <span class="block truncate font-semibold">{exercise.name}</span>
              <span class="text-xs text-base-content/60">{format_exercise_meta(exercise)}</span>
            </span>
          </span>
          <.icon name="hero-plus" class="h-4 w-4" />
        </button>
      </div>
    </section>
    """
  end

  attr :id, :string, default: nil
  attr :src, :string, default: nil
  attr :name, :string, required: true

  defp media_thumb(assigns) do
    ~H"""
    <%= if @src do %>
      <img
        id={@id}
        src={@src}
        alt={"#{@name} exercise reference"}
        class="h-10 w-10 shrink-0 rounded-lg object-cover"
        loading="lazy"
      />
    <% else %>
      <span
        id={@id}
        data-media-placeholder="true"
        class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-base-200"
      >
        <.icon name="hero-bolt" class="h-5 w-5 text-base-content/25" />
      </span>
    <% end %>
    """
  end

  attr :reference, :map, required: true

  defp form_reference_link(assigns) do
    ~H"""
    <a
      href={@reference.url}
      target={if(@reference.kind == :external, do: "_blank")}
      rel={if(@reference.kind == :external, do: "noopener noreferrer")}
      class="inline-flex items-center gap-1.5 text-xs font-semibold text-primary transition hover:text-primary/80"
    >
      {@reference.label}
      <.icon name="hero-arrow-top-right-on-square" class="h-3.5 w-3.5" />
    </a>
    """
  end

  defp format_started_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y • %H:%M")
  end

  defp format_exercise_meta(exercise) do
    [exercise.primary_muscle, exercise.equipment]
    |> Enum.filter(&(&1 && &1 != ""))
    |> Enum.join(" • ")
  end

  defp format_template_meta(template) do
    [template.primary_muscle, template.equipment]
    |> Enum.filter(&(&1 && &1 != ""))
    |> Enum.join(" • ")
  end

  defp filter_library_templates(templates, search, filter) do
    search = if is_binary(search), do: String.trim(search), else: ""
    normalized = String.downcase(search)

    templates
    |> Enum.filter(fn template ->
      matches_search =
        normalized == "" or
          String.contains?(String.downcase(template.name || ""), normalized) or
          String.contains?(String.downcase(template.primary_muscle || ""), normalized) or
          String.contains?(String.downcase(template.equipment || ""), normalized)

      matches_filter =
        case filter do
          "favorites" -> true
          "recent" -> true
          _all -> true
        end

      matches_search and matches_filter
    end)
  end

  defp format_weight(weight) do
    weight
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp workout_source_label(%{notes: "Started from plan: " <> plan_name}), do: plan_name
  defp workout_source_label(_workout), do: "Empty workout"

  defp performed_summary(workout_sets) do
    volume =
      workout_sets
      |> Enum.reduce(Decimal.new(0), fn set, acc ->
        Decimal.add(acc, Decimal.mult(set.weight || Decimal.new(0), Decimal.new(set.reps || 0)))
      end)
      |> Decimal.round(1)
      |> Decimal.normalize()
      |> Decimal.to_string(:normal)

    %{
      sets: length(workout_sets),
      reps: Enum.reduce(workout_sets, 0, &(&2 + (&1.reps || 0))),
      volume: volume
    }
  end

  defp format_rest_seconds(total_seconds) when is_integer(total_seconds) do
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)

    cond do
      minutes > 0 ->
        "#{minutes}m #{String.pad_leading(Integer.to_string(seconds), 2, "0")}s"

      true ->
        "#{seconds}s"
    end
  end
end
