defmodule FittrackWeb.WorkoutPlanLive.Generator do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def mount(_params, _session, socket) do
    form_data = %{
      "goal" => "hypertrophy",
      "equipment" => [],
      "experience" => "beginner",
      "days_per_week" => 4
    }

    {:ok,
     socket
     |> assign(:page_title, "AI Workout Generator")
     |> assign(:header, "AI Workout Generator")
     |> assign(:form, to_form(form_data, as: :ai_workout))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto space-y-8">
        <.header>
          AI Workout Generator
          <:subtitle>
            Describe your fitness goals, equipment access, and experience level to generate a 4-week plan.
          </:subtitle>
          <:actions>
            <.link navigate={~p"/workout-plans"} class="btn btn-ghost">
              <.icon name="hero-arrow-left" /> Back to plans
            </.link>
          </:actions>
        </.header>

        <.form for={@form} id="ai-workout-generator-form" phx-submit="generate" class="space-y-6">
          <.input
            field={@form[:goal]}
            type="select"
            label="Primary Goal"
            options={[
              {"Strength", "strength"},
              {"Hypertrophy", "hypertrophy"},
              {"Endurance", "endurance"},
              {"Fat Loss", "fat_loss"},
              {"General Fitness", "general"}
            ]}
            required
          />

          <.input
            field={@form[:experience]}
            type="select"
            label="Experience Level"
            options={[
              {"Beginner", "beginner"},
              {"Intermediate", "intermediate"},
              {"Advanced", "advanced"}
            ]}
            required
          />

          <.input
            field={@form[:equipment]}
            type="select"
            label="Available Equipment"
            multiple
            size="6"
            options={[
              {"Bodyweight", "Bodyweight"},
              {"Dumbbells", "Dumbbells"},
              {"Barbell", "Barbell"},
              {"Kettlebell", "Kettlebell"},
              {"Machine", "Machine"},
              {"Resistance Band", "Resistance Band"}
            ]}
          />

          <.input
            field={@form[:days_per_week]}
            type="number"
            label="Days per Week"
            min="1"
            max="7"
            required
          />

          <div class="flex justify-end gap-3">
            <.button class="btn btn-secondary" type="button" phx-click="reset_form">
              Reset
            </.button>
            <.button class="btn btn-primary" phx-disable-with="Generating...">
              Generate 4-Week Plan
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("generate", %{"ai_workout" => ai_workout_params}, socket) do
    case Training.generate_ai_workout_plan(socket.assigns.current_scope, ai_workout_params) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "AI workout plan generated and saved successfully")
         |> push_navigate(to: ~p"/workout-plans/#{workout_plan}")}

      {:error, reason} when is_binary(reason) ->
        {:noreply, socket |> put_flash(:error, "Could not generate plan: #{reason}")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not generate plan. Please adjust inputs and try again.")}
    end
  end

  @impl true
  def handle_event("reset_form", _params, socket) do
    form_data = %{
      "goal" => "hypertrophy",
      "equipment" => [],
      "experience" => "beginner",
      "days_per_week" => 4
    }

    {:noreply, assign(socket, :form, to_form(form_data, as: :ai_workout))}
  end
end
