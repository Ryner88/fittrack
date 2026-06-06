defmodule FittrackWeb.WorkoutPlanLive.Generator do
  use FittrackWeb, :live_view

  alias Fittrack.Training
  alias Fittrack.Training.WorkoutSet

  @goal_fields ~w(primary_goal secondary_goal tertiary_goal additional_goal)
  @goal_field_names [:primary_goal, :secondary_goal, :tertiary_goal, :additional_goal]
  @experience_levels ~w(beginner intermediate advanced)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "AI Workout Generator")
     |> assign(:header, "AI Workout Generator")
     |> assign(:draft_plan, nil)
     |> assign(:draft_form, nil)
     |> assign(:exercise_name_by_id, %{})
     |> assign_form(default_form_data())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl space-y-8 pb-12">
        <div class="flex flex-col gap-4 border-b border-base-200 pb-6 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-2">
            <p class="text-xs font-semibold uppercase tracking-[0.28em] text-primary/80">
              Plan Builder
            </p>
            <div class="space-y-2">
              <h1 class="text-3xl font-semibold tracking-tight text-base-content">
                AI Workout Generator
              </h1>
              <p class="max-w-2xl text-sm leading-6 text-base-content/70">
                Describe your fitness goals, equipment access, and experience level to generate a
                4-week plan.
              </p>
            </div>
          </div>

          <.link
            navigate={~p"/workout-plans"}
            class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary sm:mt-1"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to plans
          </.link>
        </div>

        <.form
          for={@form}
          id="ai-workout-generator-form"
          phx-change="validate"
          phx-submit="generate"
          class="space-y-8"
        >
          <.section_card title="Goals" description="Goals are prioritized from top to bottom.">
            <p :if={@goal_error} class="flex items-center gap-2 text-sm text-error">
              <.icon name="hero-exclamation-circle" class="size-5" />
              {@goal_error}
            </p>

            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@form[:primary_goal]}
                type="select"
                label="Primary Goal"
                class="select w-full min-h-14 text-sm"
                prompt="Select a primary goal"
                options={goal_options(@form)}
                required
              />
              <.input
                field={@form[:secondary_goal]}
                type="select"
                label="Secondary Goal"
                class="select w-full min-h-14 text-sm"
                prompt="No secondary goal"
                options={goal_options(@form, :secondary_goal)}
              />
              <.input
                field={@form[:tertiary_goal]}
                type="select"
                label="Tertiary Goal"
                class="select w-full min-h-14 text-sm"
                prompt="No tertiary goal"
                options={goal_options(@form, :tertiary_goal)}
              />
              <.input
                field={@form[:additional_goal]}
                type="select"
                label="Additional Goal"
                class="select w-full min-h-14 text-sm"
                prompt="No additional goal"
                options={goal_options(@form, :additional_goal)}
              />
            </div>
          </.section_card>

          <.section_card
            title="Profile"
            description="A few quick details help tune the weekly volume and pacing."
          >
            <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_12rem_12rem]">
              <.input
                field={@form[:experience]}
                type="select"
                label="Experience Level"
                class="select w-full min-h-14 text-sm"
                options={[
                  {"Beginner", "beginner"},
                  {"Intermediate", "intermediate"},
                  {"Advanced", "advanced"}
                ]}
                required
              />

              <div class="max-w-[12rem]">
                <.input
                  field={@form[:days_per_week]}
                  type="select"
                  label="Days per Week"
                  class="select w-full min-h-14 text-sm"
                  options={Enum.map(1..7, &{"#{&1}", &1})}
                  required
                />
              </div>

              <div class="max-w-[12rem]">
                <.input
                  field={@form[:duration_minutes]}
                  type="number"
                  label="Duration"
                  min="15"
                  max="180"
                  step="5"
                  required
                />
              </div>
            </div>
          </.section_card>

          <.section_card
            title="Preferences"
            description="Use the larger multi-choice controls to quickly mix and match what you want this plan to emphasize."
          >
            <.multi_choice_field
              label="Training Styles / Exercise Types"
              name="ai_workout[training_styles]"
              selected={@form[:training_styles].value}
              options={training_style_options()}
              helper_text="Pick every training quality you want the plan to lean into."
            />

            <.multi_choice_field
              label="Training Split"
              name="ai_workout[training_split]"
              selected={@form[:training_split].value}
              options={training_split_options()}
              helper_text="Choose any split structures that should influence the weekly layout."
            />

            <.multi_choice_field
              label="Available Equipment"
              name="ai_workout[equipment]"
              selected={@form[:equipment].value}
              options={equipment_options()}
              helper_text="Select every tool you can reliably access so the plan stays practical."
            />
          </.section_card>

          <.section_card
            title="Source Guide"
            description="Paste a workout video, article, or training guide if you want the generator to adapt its structure."
          >
            <.input
              field={@form[:source_url]}
              type="url"
              label="Website or video link (optional)"
              placeholder="https://www.youtube.com/watch?v=... or https://example.com/program"
            />
            <.input
              field={@form[:source_transcript]}
              type="textarea"
              label="Transcript or workout text (optional)"
              placeholder="Paste the video transcript or written workout if the link cannot be read."
              rows="5"
            />
            <div class="flex justify-end">
              <button
                type="submit"
                name="intent"
                value="analyze_source"
                class="inline-flex items-center justify-center rounded-full bg-secondary px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-secondary/90 disabled:opacity-70"
                phx-disable-with="Analyzing..."
              >
                Analyze Link
              </button>
            </div>
          </.section_card>

          <div class="flex flex-col-reverse gap-3 border-t border-base-200 pt-6 sm:flex-row sm:justify-end">
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              phx-click="reset_form"
            >
              Reset
            </button>

            <button
              type="submit"
              class="inline-flex min-w-[14rem] items-center justify-center rounded-full bg-primary px-5 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90 disabled:opacity-70"
              phx-disable-with="Generating..."
            >
              Generate Draft
            </button>
          </div>
        </.form>

        <section
          :if={@draft_plan}
          id="ai-workout-draft-review"
          class="rounded-2xl border border-primary/20 bg-base-100 p-5 shadow-sm md:p-6"
        >
          <div class="flex flex-col gap-3 border-b border-base-200 pb-5 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.24em] text-primary/80">
                Review Draft
              </p>
              <h2 class="mt-2 text-xl font-semibold text-base-content">
                Edit before saving
              </h2>
              <p class="mt-1 text-sm leading-6 text-base-content/70">
                Check exercise order, volume, rest, and set types before this becomes a reusable plan.
              </p>
              <p
                :if={draft_source_status(@draft_plan)}
                class="mt-2 text-sm font-medium text-base-content/70"
              >
                {draft_source_status(@draft_plan)}
              </p>
            </div>
            <button
              type="button"
              class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
              phx-click="discard_draft"
            >
              Discard
            </button>
          </div>

          <.form
            for={@draft_form}
            id="ai-workout-draft-form"
            phx-submit="save_draft"
            class="mt-6 space-y-6"
          >
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@draft_form[:name]} type="text" label="Plan Name" required />
              <.input
                field={@draft_form[:estimated_duration_minutes]}
                type="number"
                label="Duration"
                min="15"
                max="180"
                required
              />
              <div class="md:col-span-2">
                <.input
                  field={@draft_form[:description]}
                  type="textarea"
                  label="Plan Notes"
                  rows="6"
                />
              </div>
            </div>

            <div class="space-y-4">
              <div
                :for={{exercise, idx} <- Enum.with_index(@draft_plan["workout_plan_exercises"] || [])}
                id={"ai-draft-exercise-#{idx}"}
                class="rounded-2xl border border-base-200 bg-base-50 p-4"
              >
                <input
                  type="hidden"
                  name={"draft_plan[workout_plan_exercises][#{idx}][position]"}
                  value={exercise[:position] || exercise["position"]}
                />
                <input
                  type="hidden"
                  name={"draft_plan[workout_plan_exercises][#{idx}][exercise_id]"}
                  value={exercise[:exercise_id] || exercise["exercise_id"]}
                />
                <input
                  type="hidden"
                  name={"draft_plan[workout_plan_exercises][#{idx}][scheduled_day]"}
                  value={exercise[:scheduled_day] || exercise["scheduled_day"]}
                />

                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <p class="text-sm font-semibold text-base-content">
                      {exercise_name(@exercise_name_by_id, exercise)}
                    </p>
                    <p class="text-xs uppercase tracking-[0.16em] text-base-content/50">
                      {exercise[:scheduled_day] || exercise["scheduled_day"]}
                    </p>
                  </div>
                  <span class="rounded-full border border-primary/20 bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
                    {WorkoutSet.kind_label(exercise[:target_kind] || exercise["target_kind"])}
                  </span>
                </div>

                <div class="mt-4 grid gap-3 md:grid-cols-5">
                  <label class="space-y-1 text-sm font-medium text-base-content">
                    <span>Sets</span>
                    <input
                      type="number"
                      min="1"
                      name={"draft_plan[workout_plan_exercises][#{idx}][target_sets]"}
                      value={exercise[:target_sets] || exercise["target_sets"]}
                      class="input w-full"
                    />
                  </label>
                  <label class="space-y-1 text-sm font-medium text-base-content">
                    <span>Min reps</span>
                    <input
                      type="number"
                      min="1"
                      name={"draft_plan[workout_plan_exercises][#{idx}][target_reps_min]"}
                      value={exercise[:target_reps_min] || exercise["target_reps_min"]}
                      class="input w-full"
                    />
                  </label>
                  <label class="space-y-1 text-sm font-medium text-base-content">
                    <span>Max reps</span>
                    <input
                      type="number"
                      min="1"
                      name={"draft_plan[workout_plan_exercises][#{idx}][target_reps_max]"}
                      value={exercise[:target_reps_max] || exercise["target_reps_max"]}
                      class="input w-full"
                    />
                  </label>
                  <label class="space-y-1 text-sm font-medium text-base-content">
                    <span>Rest sec</span>
                    <input
                      type="number"
                      min="0"
                      name={"draft_plan[workout_plan_exercises][#{idx}][rest_seconds]"}
                      value={exercise[:rest_seconds] || exercise["rest_seconds"]}
                      class="input w-full"
                    />
                  </label>
                  <label class="space-y-1 text-sm font-medium text-base-content">
                    <span>Set type</span>
                    <select
                      name={"draft_plan[workout_plan_exercises][#{idx}][target_kind]"}
                      class="select w-full"
                    >
                      <option
                        :for={{label, value} <- WorkoutSet.kind_options()}
                        value={value}
                        selected={value == (exercise[:target_kind] || exercise["target_kind"])}
                      >
                        {label}
                      </option>
                    </select>
                  </label>
                </div>

                <label class="mt-3 block space-y-1 text-sm font-medium text-base-content">
                  <span>Notes</span>
                  <textarea
                    name={"draft_plan[workout_plan_exercises][#{idx}][notes]"}
                    rows="2"
                    class="textarea w-full"
                  ><%= exercise[:notes] || exercise["notes"] %></textarea>
                </label>
              </div>
            </div>

            <div class="flex flex-col-reverse gap-3 border-t border-base-200 pt-5 sm:flex-row sm:justify-end">
              <button
                type="button"
                class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                phx-click="discard_draft"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90 disabled:opacity-70"
                phx-disable-with="Saving..."
              >
                Save Reviewed Plan
              </button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"ai_workout" => ai_workout_params}, socket) do
    ai_workout_params = normalize_form_params(ai_workout_params)

    {:noreply, assign_form(socket, ai_workout_params, goal_error(ai_workout_params, :validate))}
  end

  @impl true
  def handle_event(
        "generate",
        %{"intent" => "analyze_source", "ai_workout" => ai_workout_params},
        socket
      ) do
    ai_workout_params = normalize_form_params(ai_workout_params)
    source_url = Map.get(ai_workout_params, "source_url")
    source_transcript = Map.get(ai_workout_params, "source_transcript")

    cond do
      is_nil(source_url) and is_nil(source_transcript) ->
        {:noreply,
         socket
         |> assign_form(ai_workout_params)
         |> put_flash(
           :error,
           "Paste a website or video link, transcript, or workout text before analyzing."
         )}

      true ->
        source_params = Map.put_new(ai_workout_params, "primary_goal", "general")

        source_params =
          if source_params["primary_goal"],
            do: source_params,
            else: Map.put(source_params, "primary_goal", "general")

        source_params = Map.put(source_params, "source_only", true)

        case Training.preview_ai_workout_plan(socket.assigns.current_scope, source_params) do
          {:ok, workout_plan_attrs} ->
            {:noreply,
             socket
             |> assign_form(ai_workout_params)
             |> assign_draft(workout_plan_attrs)
             |> put_flash(:info, "Link analyzed. Review the draft before saving.")}

          {:error, reason} when is_binary(reason) ->
            {:noreply, socket |> assign_form(ai_workout_params) |> put_flash(:error, reason)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign_form(ai_workout_params)
             |> put_flash(
               :error,
               "Could not analyze that link. Try another source or use the manual generator."
             )}
        end
    end
  end

  def handle_event("generate", %{"ai_workout" => ai_workout_params}, socket) do
    ai_workout_params = normalize_form_params(ai_workout_params)

    case goal_error(ai_workout_params, :submit) do
      nil ->
        case Training.preview_ai_workout_plan(socket.assigns.current_scope, ai_workout_params) do
          {:ok, workout_plan_attrs} ->
            {:noreply,
             socket
             |> assign_form(ai_workout_params)
             |> assign_draft(workout_plan_attrs)
             |> put_flash(:info, "AI workout draft generated. Review it before saving.")}

          {:error, reason} when is_binary(reason) ->
            {:noreply, socket |> assign_form(ai_workout_params) |> put_flash(:error, reason)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign_form(ai_workout_params)
             |> put_flash(:error, "Could not generate plan. Please adjust inputs and try again.")}
        end

      error ->
        {:noreply,
         socket
         |> assign_form(ai_workout_params, error)
         |> put_flash(:error, error)}
    end
  end

  @impl true
  def handle_event("reset_form", _params, socket) do
    {:noreply,
     socket
     |> clear_draft()
     |> assign_form(default_form_data())}
  end

  @impl true
  def handle_event("discard_draft", _params, socket) do
    {:noreply, clear_draft(socket)}
  end

  @impl true
  def handle_event("save_draft", %{"draft_plan" => draft_params}, socket) do
    draft_params = normalize_draft_params(socket.assigns.draft_plan, draft_params)

    case Training.create_workout_plan(socket.assigns.current_scope, draft_params) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "AI workout plan saved successfully")
         |> push_navigate(to: ~p"/workout-plans/#{workout_plan}")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket
         |> assign_draft(draft_params)
         |> put_flash(:error, "Review the highlighted fields before saving.")}
    end
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  defp section_card(assigns) do
    ~H"""
    <section class="rounded-2xl border border-base-200 bg-base-100 p-5 shadow-sm md:p-6">
      <div class="space-y-6">
        <div class="space-y-1">
          <h2 class="text-lg font-semibold text-base-content">{@title}</h2>
          <p :if={@description} class="text-sm leading-6 text-base-content/70">{@description}</p>
        </div>
        <div class="space-y-5">
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :selected, :list, default: []
  attr :helper_text, :string, default: nil
  attr :errors, :list, default: []

  defp multi_choice_field(assigns) do
    assigns =
      assigns
      |> assign(:selected, normalize_multi_values(assigns.selected))
      |> assign(:input_name, assigns.name <> "[]")

    ~H"""
    <div class="space-y-3">
      <div class="space-y-1">
        <h3 class="text-sm font-medium text-base-content">{@label}</h3>
        <p :if={@helper_text} class="text-sm leading-6 text-base-content/70">{@helper_text}</p>
      </div>

      <input type="hidden" name={@input_name} value="" />

      <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <%= for {option_label, option_value} <- @options do %>
          <% selected? = option_value in @selected %>
          <label class={[
            "group flex min-h-14 cursor-pointer items-center justify-between gap-3 rounded-2xl border px-4 py-3 transition duration-150 ease-out",
            "border-base-300 bg-base-100 text-base-content hover:border-primary/40 hover:bg-base-200/60",
            selected? && "border-primary bg-primary/10 text-primary shadow-sm"
          ]}>
            <input
              type="checkbox"
              name={@input_name}
              value={option_value}
              checked={selected?}
              class="sr-only"
            />
            <span class="text-sm font-medium leading-5">{option_label}</span>
            <span class={[
              "flex size-6 shrink-0 items-center justify-center rounded-full border transition",
              selected? && "border-primary bg-primary text-primary-content",
              !selected? &&
                "border-base-300 bg-base-100 text-transparent group-hover:border-primary/40"
            ]}>
              <.icon name="hero-check" class="size-4" />
            </span>
          </label>
        <% end %>
      </div>

      <p :for={msg <- @errors} class="flex items-center gap-2 text-sm text-error">
        <.icon name="hero-exclamation-circle" class="size-5" />
        {msg}
      </p>
    </div>
    """
  end

  defp assign_form(socket, form_data, goal_error \\ nil) do
    socket
    |> assign(:goal_error, goal_error)
    |> assign(:form, to_form(form_data, as: :ai_workout))
  end

  defp default_form_data do
    %{
      "primary_goal" => nil,
      "secondary_goal" => nil,
      "tertiary_goal" => nil,
      "additional_goal" => nil,
      "training_styles" => [],
      "training_split" => [],
      "equipment" => [],
      "experience" => "beginner",
      "days_per_week" => 4,
      "duration_minutes" => 45,
      "source_url" => nil,
      "source_transcript" => nil
    }
  end

  defp normalize_form_params(params) do
    %{
      "primary_goal" => normalize_goal_value(Map.get(params, "primary_goal")),
      "secondary_goal" => normalize_goal_value(Map.get(params, "secondary_goal")),
      "tertiary_goal" => normalize_goal_value(Map.get(params, "tertiary_goal")),
      "additional_goal" => normalize_goal_value(Map.get(params, "additional_goal")),
      "training_styles" => normalize_multi_values(Map.get(params, "training_styles", [])),
      "training_split" => normalize_multi_values(Map.get(params, "training_split", [])),
      "equipment" => normalize_multi_values(Map.get(params, "equipment", [])),
      "experience" =>
        normalize_choice(Map.get(params, "experience"), @experience_levels, "beginner"),
      "days_per_week" => normalize_days_per_week(Map.get(params, "days_per_week", 4)),
      "duration_minutes" => normalize_duration_minutes(Map.get(params, "duration_minutes", 45)),
      "source_url" => normalize_source_url(Map.get(params, "source_url")),
      "source_transcript" => normalize_source_transcript(Map.get(params, "source_transcript"))
    }
  end

  defp normalize_goal_value(nil), do: nil

  defp normalize_goal_value(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_multi_values(values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_multi_values(values) when is_binary(values) do
    values
    |> String.split(",", trim: true)
    |> normalize_multi_values()
  end

  defp normalize_multi_values(_), do: []

  defp normalize_choice(nil, _allowed, default), do: default

  defp normalize_choice(value, allowed, default) do
    value =
      value
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if value in allowed, do: value, else: default
  end

  defp normalize_days_per_week(value) when is_integer(value) and value in 1..7, do: value

  defp normalize_days_per_week(value) when is_binary(value) do
    case Integer.parse(value) do
      {days, _} when days in 1..7 -> days
      _ -> 4
    end
  end

  defp normalize_days_per_week(_), do: 4

  defp normalize_duration_minutes(value) when is_integer(value) and value in 15..180, do: value

  defp normalize_duration_minutes(value) when is_binary(value) do
    case Integer.parse(value) do
      {minutes, _} when minutes in 15..180 -> minutes
      _ -> 45
    end
  end

  defp normalize_duration_minutes(_), do: 45

  defp normalize_source_url(nil), do: nil

  defp normalize_source_url(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_source_transcript(nil), do: nil

  defp normalize_source_transcript(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp goal_error(params, mode) do
    goals =
      @goal_fields
      |> Enum.map(&Map.get(params, &1))
      |> Enum.reject(&is_nil/1)

    cond do
      mode == :submit and is_nil(Map.get(params, "primary_goal")) ->
        "Primary Goal is required."

      Enum.uniq(goals) != goals ->
        "Each goal must be unique."

      true ->
        nil
    end
  end

  defp goal_options(form, current_field \\ :primary_goal) do
    current_value = normalize_goal_value(form[current_field].value)

    selected_elsewhere =
      @goal_field_names
      |> Enum.reject(&(&1 == current_field))
      |> Enum.map(&(form[&1].value |> normalize_goal_value()))
      |> Enum.reject(&is_nil/1)

    all_goal_options()
    |> Enum.reject(fn {_label, value} -> value in selected_elsewhere end)
    |> Enum.sort_by(fn {_label, value} -> value != current_value end)
  end

  defp all_goal_options do
    [
      {"Strength", "strength"},
      {"Hypertrophy", "hypertrophy"},
      {"Endurance", "endurance"},
      {"Fat Loss", "fat_loss"},
      {"General Fitness", "general"}
    ]
  end

  defp training_style_options do
    [
      {"Cardio", "cardio"},
      {"Strength", "strength"},
      {"Hypertrophy", "hypertrophy"},
      {"Isometric", "isometric"},
      {"Speed", "speed"},
      {"Power", "power"},
      {"Plyometric", "plyometric"},
      {"Mobility", "mobility"},
      {"Conditioning", "conditioning"},
      {"Core", "core"},
      {"Balance", "balance"},
      {"Functional", "functional"},
      {"Bodybuilding", "bodybuilding"},
      {"Calisthenics", "calisthenics"}
    ]
  end

  defp training_split_options do
    [
      {"Full Body", "full_body"},
      {"Upper / Lower", "upper_lower"},
      {"Push / Pull / Legs", "push_pull_legs"},
      {"Body Part Split", "body_part_split"},
      {"Athletic Performance", "athletic_performance"},
      {"Circuit Based", "circuit_based"},
      {"Strength Focused", "strength_focused"},
      {"Hybrid", "hybrid"}
    ]
  end

  defp equipment_options do
    [
      {"Bodyweight", "bodyweight"},
      {"Dumbbells", "dumbbell"},
      {"Barbell", "barbell"},
      {"Bench", "bench"},
      {"Machines", "machine"},
      {"Kettlebells", "kettlebell"},
      {"Resistance Bands", "band"},
      {"Cable Machine", "cable"},
      {"Pull-Up Bar", "pull-up bar"},
      {"Cardio Machines", "cardio machine"}
    ]
  end

  defp assign_draft(socket, workout_plan_attrs) do
    exercise_name_by_id =
      socket.assigns.current_scope
      |> Training.list_exercises()
      |> Map.new(fn exercise -> {exercise.id, exercise.name} end)

    socket
    |> assign(:draft_plan, workout_plan_attrs)
    |> assign(:draft_form, to_form(workout_plan_attrs, as: :draft_plan))
    |> assign(:exercise_name_by_id, exercise_name_by_id)
  end

  defp clear_draft(socket) do
    socket
    |> assign(:draft_plan, nil)
    |> assign(:draft_form, nil)
    |> assign(:exercise_name_by_id, %{})
  end

  defp normalize_draft_params(original_draft, draft_params) do
    original_draft
    |> Map.merge(%{
      "name" =>
        normalize_required_text(Map.get(draft_params, "name"), Map.get(original_draft, "name")),
      "description" =>
        normalize_required_text(
          Map.get(draft_params, "description"),
          Map.get(original_draft, "description")
        ),
      "estimated_duration_minutes" =>
        normalize_duration_minutes(
          Map.get(draft_params, "estimated_duration_minutes") ||
            Map.get(original_draft, "estimated_duration_minutes")
        ),
      "workout_plan_exercises" =>
        normalize_draft_exercises(Map.get(draft_params, "workout_plan_exercises", %{}))
    })
  end

  defp normalize_required_text(nil, fallback), do: fallback

  defp normalize_required_text(value, fallback) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> fallback
      normalized -> normalized
    end
  end

  defp normalize_draft_exercises(exercises) when is_map(exercises) do
    exercises
    |> Enum.sort_by(fn {idx, _exercise} ->
      case Integer.parse(to_string(idx)) do
        {index, _} -> index
        :error -> 0
      end
    end)
    |> Enum.map(fn {_idx, exercise} ->
      %{
        "position" => normalize_positive_integer(Map.get(exercise, "position"), 1),
        "exercise_id" => normalize_positive_integer(Map.get(exercise, "exercise_id"), nil),
        "target_sets" => normalize_positive_integer(Map.get(exercise, "target_sets"), 3),
        "target_reps_min" => normalize_positive_integer(Map.get(exercise, "target_reps_min"), 8),
        "target_reps_max" => normalize_positive_integer(Map.get(exercise, "target_reps_max"), 12),
        "rest_seconds" => normalize_non_negative_integer(Map.get(exercise, "rest_seconds"), 60),
        "target_kind" => normalize_set_type(Map.get(exercise, "target_kind")),
        "scheduled_day" => normalize_required_text(Map.get(exercise, "scheduled_day"), nil),
        "notes" => normalize_required_text(Map.get(exercise, "notes"), "")
      }
    end)
  end

  defp normalize_draft_exercises(_), do: []

  defp normalize_positive_integer(value, fallback) do
    case Integer.parse(to_string(value || "")) do
      {integer, _} when integer > 0 -> integer
      _ -> fallback
    end
  end

  defp normalize_non_negative_integer(value, fallback) do
    case Integer.parse(to_string(value || "")) do
      {integer, _} when integer >= 0 -> integer
      _ -> fallback
    end
  end

  defp normalize_set_type(value) do
    value = to_string(value || "straight_set")

    if value in WorkoutSet.kinds() do
      value
    else
      "straight_set"
    end
  end

  defp exercise_name(exercise_name_by_id, exercise) do
    exercise_id = exercise[:exercise_id] || exercise["exercise_id"]

    Map.get(exercise_name_by_id, exercise_id, "Exercise ##{exercise_id}")
  end

  defp draft_source_status(nil), do: nil

  defp draft_source_status(%{"description" => description}) when is_binary(description) do
    cond do
      String.contains?(description, "Source guide:") and
          String.contains?(description, "Safety review:") ->
        "Linked source was analyzed. Review the structured draft before saving."

      String.contains?(description, "Source guide:") ->
        "Linked source was fetched, but structured AI parsing was not available. Review the fallback draft carefully."

      true ->
        nil
    end
  end

  defp draft_source_status(_), do: nil
end
