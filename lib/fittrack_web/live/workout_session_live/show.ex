defmodule FittrackWeb.WorkoutSessionLive.Show do
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
            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Workout session</p>
            <h1 class="mt-2 text-2xl font-semibold text-base-content">
              {format_started_at(@workout_session.started_at)}
            </h1>
            <p class="mt-1 text-sm text-base-content/70">
              <%= if @workout_session.notes && @workout_session.notes != "" do %>
                {@workout_session.notes}
              <% else %>
                No notes added yet.
              <% end %>
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/sessions"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Back to history
            </.link>
            <.link
              navigate={~p"/exercises"}
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              Manage exercises
            </.link>
          </div>
        </div>

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
                  navigate={~p"/exercises/new"}
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
                    label="Weight"
                    required
                    placeholder="e.g. 135"
                  />
                  <.input
                    field={@form[:reps]}
                    type="number"
                    label="Reps"
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
            <% end %>
          </div>

          <aside class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <div>
              <h2 class="text-lg font-semibold text-base-content">Library</h2>
              <p class="text-sm text-base-content/70">
                Add a shared template to your personal exercise list in one tap.
              </p>
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
                    <div>
                      <p class="text-sm font-semibold text-base-content">{template.name}</p>
                      <p class="mt-1 text-xs text-base-content/60">
                        {format_template_meta(template)}
                      </p>
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
            <h2 class="text-lg font-semibold text-base-content">Session sets</h2>
            <span class="text-xs uppercase tracking-[0.2em] text-base-content/50">
              {format_started_at(@workout_session.started_at)}
            </span>
          </div>

          <div
            id="workout-sets"
            phx-update="stream"
            class="mt-4 grid gap-4 sm:grid-cols-2"
          >
            <div class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100/60 p-6 text-center text-sm text-base-content/70">
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
  def mount(%{"id" => id}, _session, socket) do
    workout_session = Training.get_workout_session!(socket.assigns.current_scope, id)
    exercise_options = exercise_options(socket.assigns.current_scope)
    templates = Training.list_exercise_templates(%{})

    {:ok,
     socket
     |> assign(:page_title, "Workout Session")
     |> assign(:workout_session, workout_session)
     |> assign(:exercise_options, exercise_options)
     |> assign(:form, to_form(Training.change_workout_set(%WorkoutSet{})))
     |> assign(:kind_options, WorkoutSet.kind_options())
     |> assign(:library_templates, templates)
     |> assign(:filtered_library, templates)
     |> assign(:library_filter, "all")
     |> assign(:library_search, "")
     |> assign(:library_form, to_form(%{"search" => ""}, as: :library))
     |> stream(:workout_sets, workout_session.workout_sets)}
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
         |> assign(:form, to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That template is no longer available.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to add this template.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to add the template right now.")}
    end
  end

  def handle_event("validate", %{"workout_set" => params}, socket) do
    changeset = Training.change_workout_set(%WorkoutSet{}, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"workout_set" => params}, socket) do
    case Training.create_workout_set(
           socket.assigns.current_scope,
           socket.assigns.workout_session,
           params
         ) do
      {:ok, workout_set} ->
        {:noreply,
         socket
         |> stream_insert(:workout_sets, workout_set, at: -1)
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

  defp format_started_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y • %H:%M")
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
