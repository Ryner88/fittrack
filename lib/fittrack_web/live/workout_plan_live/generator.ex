defmodule FittrackWeb.WorkoutPlanLive.Generator do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @goal_fields ~w(primary_goal secondary_goal tertiary_goal additional_goal)
  @goal_field_names [:primary_goal, :secondary_goal, :tertiary_goal, :additional_goal]
  @experience_levels ~w(beginner intermediate advanced)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "AI Workout Generator")
     |> assign(:header, "AI Workout Generator")
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

          <.link navigate={~p"/workout-plans"} class="btn btn-ghost btn-sm sm:mt-1">
            <.icon name="hero-arrow-left" /> Back to plans
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
            <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_12rem]">
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

          <div class="flex flex-col-reverse gap-3 border-t border-base-200 pt-6 sm:flex-row sm:justify-end">
            <button type="button" class="btn btn-ghost" phx-click="reset_form">
              Reset
            </button>

            <button
              type="submit"
              class="btn btn-primary min-w-[14rem]"
              phx-disable-with="Generating..."
            >
              Generate 4-Week Plan
            </button>
          </div>
        </.form>
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
  def handle_event("generate", %{"ai_workout" => ai_workout_params}, socket) do
    ai_workout_params = normalize_form_params(ai_workout_params)

    case goal_error(ai_workout_params, :submit) do
      nil ->
        case Training.generate_ai_workout_plan(socket.assigns.current_scope, ai_workout_params) do
          {:ok, workout_plan} ->
            {:noreply,
             socket
             |> put_flash(:info, "AI workout plan generated and saved successfully")
             |> push_navigate(to: ~p"/workout-plans/#{workout_plan}")}

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
    {:noreply, assign_form(socket, default_form_data())}
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block, required: true

  defp section_card(assigns) do
    ~H"""
    <section class="rounded-3xl border border-base-200 bg-base-100 p-5 shadow-sm md:p-6">
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
      "days_per_week" => 4
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
      "days_per_week" => normalize_days_per_week(Map.get(params, "days_per_week", 4))
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
end
