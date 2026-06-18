defmodule FittrackWeb.LibraryLive.Show do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <article class="mx-auto max-w-6xl space-y-8">
        <div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
          <div class="max-w-3xl">
            <.link
              navigate={~p"/exercises"}
              class="inline-flex items-center gap-2 text-sm font-semibold text-primary transition hover:text-primary/80"
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" /> Exercise library
            </.link>
            <h1 class="mt-4 text-3xl font-semibold text-base-content sm:text-5xl">
              {@template.name}
            </h1>
            <p class="mt-3 text-lg text-base-content/70">{summary_line(@template)}</p>
            <div class="mt-5 flex flex-wrap gap-2">
              <.pill :for={alias <- @template.aliases} label={alias.name} icon="hero-tag" />
              <.pill
                :if={@template.difficulty}
                label={String.capitalize(@template.difficulty)}
                icon="hero-signal"
              />
              <.pill
                :if={@template.exercise_category}
                label={format_label(@template.exercise_category)}
                icon="hero-squares-2x2"
              />
            </div>
          </div>

          <div class="flex flex-wrap gap-3">
            <button
              :if={@current_scope && @current_scope.user}
              id="add-template-to-my-exercises"
              phx-click="add_to_library"
              phx-value-template_id={@template.id}
              class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Add to My Exercises
            </button>
            <.link
              :if={!(@current_scope && @current_scope.user)}
              navigate={~p"/users/log-in"}
              class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" /> Log in to add
            </.link>
          </div>
        </div>

        <section
          :if={@current_scope && @current_scope.user}
          id="add-to-workout-panel"
          class="rounded-lg border border-primary/20 bg-primary/5 p-5 shadow-sm"
        >
          <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <p class="text-sm font-semibold text-primary">Add to Workout</p>
              <h2 class="mt-1 text-xl font-semibold text-base-content">
                Put {@template.name} into today's training.
              </h2>
              <p class="mt-1 text-sm text-base-content/70">
                Choose an existing workout or start a new one with this exercise selected.
              </p>
            </div>
            <.form
              for={@workout_form}
              id="add-to-workout-form"
              phx-submit="add_to_workout"
              class="grid gap-3 sm:min-w-[28rem] sm:grid-cols-[1fr_auto] sm:items-end"
            >
              <div class="grid gap-3 sm:grid-cols-2">
                <.input
                  field={@workout_form[:workout_id]}
                  type="select"
                  label="Workout"
                  options={@workout_options}
                />
                <.input
                  field={@workout_form[:name]}
                  type="text"
                  label="New workout name"
                  placeholder={default_workout_name(@template)}
                />
              </div>
              <button
                type="submit"
                phx-disable-with="Adding..."
                class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-primary/90 disabled:opacity-70"
              >
                <.icon name="hero-plus" class="h-4 w-4" /> Add
              </button>
            </.form>
          </div>
        </section>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,1.35fr)_minmax(20rem,0.65fr)]">
          <div class="space-y-6">
            <% media_urls = exercise_media_urls(@template) %>
            <section
              id="exercise-media"
              class="overflow-hidden rounded-lg border border-base-200 bg-base-100 shadow-sm"
            >
              <%= if media_urls == [] do %>
                <div
                  id={"exercise-detail-media-placeholder-#{@template.id}"}
                  data-media-placeholder="true"
                  class="flex aspect-[16/9] items-center justify-center bg-gradient-to-br from-base-200 to-base-300"
                >
                  <.icon name="hero-bolt" class="h-12 w-12 text-base-content/25" />
                </div>
              <% else %>
                <div class="grid gap-2">
                  <img
                    :for={media_url <- media_urls}
                    src={media_url}
                    alt={"#{@template.name} exercise reference"}
                    class="max-h-[34rem] w-full object-cover"
                  />
                </div>
              <% end %>
            </section>

            <section
              id="exercise-instructions"
              class="rounded-lg border border-base-200 bg-base-100 p-6 shadow-sm"
            >
              <h2 class="text-xl font-semibold text-base-content">Instructions</h2>
              <div class="mt-4 whitespace-pre-line text-sm leading-6 text-base-content/80">
                {instructions(@template)}
              </div>
            </section>

            <section id="exercise-relationships" class="grid gap-4 md:grid-cols-2">
              <.relationship_panel
                title="Variations"
                empty_label="No variations linked yet."
                relationships={variation_templates(@template)}
              />
              <.relationship_panel
                title="Substitutions"
                empty_label="No substitutions linked yet."
                relationships={substitution_templates(@template)}
              />
            </section>
          </div>

          <aside class="space-y-4">
            <section
              id="exercise-muscles"
              class="rounded-lg border border-base-200 bg-base-100 p-5 shadow-sm"
            >
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Muscles
              </h2>
              <div class="mt-3 flex flex-wrap gap-2">
                <.pill :for={muscle <- muscle_names(@template)} label={muscle} />
              </div>
            </section>

            <section
              id="exercise-equipment"
              class="rounded-lg border border-base-200 bg-base-100 p-5 shadow-sm"
            >
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Equipment
              </h2>
              <div class="mt-3 flex flex-wrap gap-2">
                <.pill
                  :for={equipment <- equipment_names(@template)}
                  label={equipment}
                  icon="hero-wrench-screwdriver"
                />
              </div>
            </section>

            <section
              id="exercise-tags"
              class="rounded-lg border border-base-200 bg-base-100 p-5 shadow-sm"
            >
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">Tags</h2>
              <div class="mt-3 flex flex-wrap gap-2">
                <.pill :for={tag <- tags(@template)} label={format_label(tag)} icon="hero-tag" />
                <p :if={Enum.empty?(tags(@template))} class="text-sm text-base-content/60">
                  No tags yet.
                </p>
              </div>
            </section>

            <section
              id="exercise-details"
              class="rounded-lg border border-base-200 bg-base-100 p-5 shadow-sm"
            >
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Details
              </h2>
              <dl class="mt-3 divide-y divide-base-200 text-sm">
                <.detail_row label="Difficulty" value={format_label(@template.difficulty)} />
                <.detail_row label="Category" value={format_label(@template.exercise_category)} />
                <.detail_row label="Pattern" value={format_label(@template.movement_pattern)} />
                <.detail_row label="Direction" value={format_label(@template.movement_direction)} />
                <.detail_row label="Skill" value={format_label(@template.skill_requirement)} />
              </dl>
            </section>
          </aside>
        </div>
      </article>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Training.get_exercise_template_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Exercise not found")
         |> push_navigate(to: ~p"/exercises")}

      template ->
        {:ok,
         socket
         |> assign(:page_title, template.name)
         |> assign(:template, template)
         |> assign_workout_picker()}
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
         |> push_navigate(to: ~p"/my-exercises/#{exercise}")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Exercise template not found")}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Log in to add exercises to your library.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  def handle_event("add_to_workout", %{"workout" => workout_params}, socket) do
    workout_id = Map.get(workout_params, "workout_id")

    with {:ok, exercise} <-
           Training.add_template_to_user(socket.assigns.current_scope, socket.assigns.template.id),
         {:ok, workout} <-
           workout_for_add(socket.assigns.current_scope, workout_id, exercise, workout_params) do
      {:noreply,
       socket
       |> put_flash(:info, "#{exercise.name} added. Log your first set.")
       |> push_navigate(to: ~p"/workouts/#{workout}?exercise_id=#{exercise.id}")}
    else
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That workout is no longer available.")}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Log in to add exercises to workouts.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         put_flash(socket, :error, "Unable to start workout: #{changeset_error(changeset)}")}
    end
  end

  attr :label, :string, required: true
  attr :icon, :string, default: nil

  defp pill(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 rounded-full bg-base-200 px-3 py-1 text-xs font-semibold text-base-content/75">
      <.icon :if={@icon} name={@icon} class="h-3.5 w-3.5" /> {@label}
    </span>
    """
  end

  attr :title, :string, required: true
  attr :empty_label, :string, required: true
  attr :relationships, :list, required: true

  defp relationship_panel(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-200 bg-base-100 p-5 shadow-sm">
      <h2 class="text-lg font-semibold text-base-content">{@title}</h2>
      <div class="mt-3 space-y-2">
        <.link
          :for={template <- @relationships}
          navigate={~p"/exercises/#{template.slug}"}
          class="flex items-center justify-between rounded-lg border border-base-200 px-3 py-2 text-sm transition hover:border-primary/30 hover:text-primary"
        >
          <span class="font-semibold">{template.name}</span>
          <.icon name="hero-arrow-right" class="h-4 w-4" />
        </.link>
        <p :if={Enum.empty?(@relationships)} class="text-sm text-base-content/60">{@empty_label}</p>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp detail_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 py-2">
      <dt class="text-base-content/60">{@label}</dt>
      <dd class="text-right font-semibold text-base-content">{@value || "Not set"}</dd>
    </div>
    """
  end

  defp instructions(template),
    do: template.notes || "Instructions for this exercise are not available yet."

  defp summary_line(template) do
    [
      template.exercise_category,
      List.first(muscle_names(template)),
      List.first(equipment_names(template))
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&format_label/1)
    |> Enum.join(" • ")
  end

  defp muscle_names(template) do
    normalized =
      template.template_muscles
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.exercise_muscle.name)

    Enum.uniq(normalized ++ [template.primary_muscle | template.secondary_muscles || []])
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp equipment_names(template) do
    normalized =
      template.template_equipment
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.exercise_equipment.name)

    Enum.uniq(normalized ++ [template.equipment])
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp tags(template) do
    Enum.uniq((template.weighted_tags || []) ++ (template.training_style_tags || []))
  end

  defp variation_templates(template) do
    Enum.map(template.variations, & &1.variation_exercise_template)
  end

  defp substitution_templates(template) do
    template.substitutions
    |> Enum.sort_by(& &1.priority)
    |> Enum.map(& &1.substitute_exercise_template)
  end

  defp assign_workout_picker(%{assigns: %{current_scope: %{user: user}}} = socket)
       when not is_nil(user) do
    workouts = Training.list_workouts(socket.assigns.current_scope)

    socket
    |> assign(:workout_options, [{"New workout", "new"} | Enum.map(workouts, &workout_option/1)])
    |> assign(:workout_form, to_form(%{"workout_id" => "new", "name" => ""}, as: :workout))
  end

  defp assign_workout_picker(socket) do
    socket
    |> assign(:workout_options, [])
    |> assign(:workout_form, to_form(%{"workout_id" => "new", "name" => ""}, as: :workout))
  end

  defp workout_for_add(current_scope, "new", exercise, params) do
    name = params |> Map.get("name") |> normalize_workout_name(default_workout_name(exercise))

    Training.create_workout(current_scope, %{
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      notes: name
    })
  end

  defp workout_for_add(current_scope, workout_id, _exercise, _params) do
    current_scope
    |> Training.list_workouts()
    |> Enum.find(&(&1.id == parse_id(workout_id)))
    |> case do
      nil -> {:error, :not_found}
      workout -> {:ok, workout}
    end
  end

  defp workout_option(workout) do
    sets = workout.workout_sets || []

    date_label =
      if Date.compare(DateTime.to_date(workout.started_at), Date.utc_today()) == :eq do
        "Today"
      else
        Calendar.strftime(workout.started_at, "%b %d")
      end

    name = normalize_workout_name(workout.notes, "Workout")
    label = "#{date_label} - #{name} • #{length(sets)} sets"

    {label, workout.id}
  end

  defp default_workout_name(%{primary_muscle: muscle}) when muscle not in [nil, ""] do
    "#{muscle} day"
  end

  defp default_workout_name(%{name: name}) when name not in [nil, ""] do
    "#{name} session"
  end

  defp default_workout_name(_), do: "Training session"

  defp normalize_workout_name(value, default) when is_binary(value) do
    case String.trim(value) do
      "" -> default
      name -> name
    end
  end

  defp normalize_workout_name(_value, default), do: default

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_id(_value), do: nil

  defp format_label(nil), do: nil
  defp format_label(""), do: nil

  defp format_label(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp changeset_error(changeset) do
    changeset.errors
    |> List.first()
    |> case do
      {field, {message, _opts}} -> "#{field} #{message}"
      nil -> "please try again"
    end
  end
end
