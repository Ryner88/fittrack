defmodule FittrackWeb.OneRepMaxLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def mount(_params, _session, socket) do
    params = %{"exercise_id" => "", "weight" => "", "reps" => "5", "unit" => "lb"}
    exercise_options = exercise_options(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "1RM Calculator")
     |> assign(:exercise_options, exercise_options)
     |> assign(:result, nil)
     |> assign(:form, to_form(params, as: :one_rep_max))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-5xl space-y-8 pb-12">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="space-y-2">
            <p class="text-xs font-semibold uppercase tracking-[0.24em] text-primary/80">
              Strength Tools
            </p>
            <h1 class="text-3xl font-semibold tracking-tight text-base-content">
              1RM Calculator
            </h1>
            <p class="max-w-2xl text-sm leading-6 text-base-content/70">
              Pick an exercise, enter the heaviest set you have completed, and estimate how much you can lift for one rep.
            </p>
          </div>

          <.link navigate={~p"/dashboard"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Dashboard
          </.link>
        </div>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)]">
          <section class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-base-content">Lift details</h2>
            <p class="mt-1 text-sm text-base-content/70">
              Best accuracy comes from your highest stable set of 2-10 reps for the selected exercise.
            </p>

            <.form
              for={@form}
              id="one-rep-max-form"
              phx-change="calculate"
              phx-submit="calculate"
              class="mt-6 space-y-4"
            >
              <.input
                field={@form[:exercise_id]}
                type="select"
                label="Exercise"
                prompt="Manual / no exercise selected"
                options={@exercise_options}
              />
              <.input
                field={@form[:weight]}
                type="number"
                label="Heaviest weight lifted"
                min="0"
                step="0.5"
                required
              />
              <.input
                field={@form[:reps]}
                type="number"
                label="Reps completed at that weight"
                min="1"
                max="30"
                required
              />
              <.input
                field={@form[:bodyweight]}
                type="number"
                label="Bodyweight (optional)"
                min="0"
                step="0.5"
              />
              <.input
                field={@form[:unit]}
                type="select"
                label="Unit"
                options={[{"Pounds", "lb"}, {"Kilograms", "kg"}]}
              />

              <button type="submit" class="btn btn-primary w-full" phx-disable-with="Calculating...">
                Calculate
              </button>
            </.form>
          </section>

          <section
            id="one-rep-max-results"
            class="rounded-2xl border border-base-200 bg-base-100 p-6 shadow-sm"
          >
            <%= if @result do %>
              <div class="grid gap-4 sm:grid-cols-3">
                <div class="rounded-xl border border-primary/20 bg-primary/10 p-4">
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                    Estimated One-Rep Max
                  </p>
                  <p class="mt-2 text-3xl font-semibold text-base-content">
                    {@result.one_rep_max} {@result.unit}
                  </p>
                  <p class="mt-2 text-sm font-medium text-primary/80">
                    {@result.exercise_name}
                  </p>
                </div>
                <div class="rounded-xl border border-base-200 bg-base-50 p-4">
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">
                    Formula
                  </p>
                  <p class="mt-2 text-xl font-semibold text-base-content">Epley</p>
                </div>
                <div class="rounded-xl border border-base-200 bg-base-50 p-4">
                  <p class="text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">
                    Relative Strength
                  </p>
                  <p class="mt-2 text-xl font-semibold text-base-content">
                    {@result.strength_standard}
                  </p>
                </div>
              </div>

              <div class="mt-6 overflow-hidden rounded-xl border border-base-200">
                <table class="w-full text-left text-sm">
                  <thead class="bg-base-200/70 text-xs uppercase tracking-[0.16em] text-base-content/60">
                    <tr>
                      <th class="px-4 py-3">Percent</th>
                      <th class="px-4 py-3">Load</th>
                      <th class="px-4 py-3">Use</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-base-200">
                    <tr :for={row <- @result.percentages}>
                      <td class="px-4 py-3 font-semibold text-base-content">{row.percent}%</td>
                      <td class="px-4 py-3 text-base-content/80">{row.load} {@result.unit}</td>
                      <td class="px-4 py-3 text-base-content/70">{row.use}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% else %>
              <div class="flex min-h-80 items-center justify-center rounded-xl border border-dashed border-base-300 bg-base-50 p-8 text-center">
                <div class="space-y-3">
                  <.icon name="hero-calculator" class="mx-auto size-10 text-base-content/30" />
                  <p class="text-sm text-base-content/70">
                    Select an exercise and enter your heaviest set to estimate what you can lift for one rep.
                  </p>
                </div>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("calculate", %{"one_rep_max" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :one_rep_max))
     |> assign(:result, calculate(params, socket.assigns.exercise_options))}
  end

  defp calculate(params, exercise_options) do
    with {:ok, weight} <- parse_positive_decimal(Map.get(params, "weight")),
         {:ok, reps} <- parse_reps(Map.get(params, "reps")) do
      unit = normalize_unit(Map.get(params, "unit"))
      one_rep_max = Decimal.mult(weight, Decimal.add(Decimal.new(1), Decimal.div(reps, 30)))
      rounded_max = one_rep_max |> Decimal.round(1) |> Decimal.normalize()
      bodyweight = parse_optional_decimal(Map.get(params, "bodyweight"))

      %{
        exercise_name: exercise_name(Map.get(params, "exercise_id"), exercise_options),
        one_rep_max: Decimal.to_string(rounded_max, :normal),
        unit: unit,
        percentages: percentage_rows(rounded_max),
        strength_standard: strength_standard(rounded_max, bodyweight)
      }
    else
      _ -> nil
    end
  end

  defp parse_positive_decimal(value) do
    case Decimal.parse(to_string(value || "")) do
      {decimal, ""} ->
        if Decimal.compare(decimal, Decimal.new(0)) == :gt, do: {:ok, decimal}, else: :error

      _ ->
        :error
    end
  end

  defp parse_optional_decimal(value) do
    case Decimal.parse(to_string(value || "")) do
      {decimal, ""} ->
        if Decimal.compare(decimal, Decimal.new(0)) == :gt, do: decimal, else: nil

      _ ->
        nil
    end
  end

  defp parse_reps(value) do
    case Integer.parse(to_string(value || "")) do
      {reps, ""} when reps in 1..30 -> {:ok, Decimal.new(reps)}
      _ -> :error
    end
  end

  defp normalize_unit("kg"), do: "kg"
  defp normalize_unit(_), do: "lb"

  defp exercise_options(scope) do
    scope
    |> Training.list_exercises()
    |> Enum.map(fn exercise -> {exercise.name, exercise.id} end)
  end

  defp exercise_name(nil, _exercise_options), do: "Manual estimate"
  defp exercise_name("", _exercise_options), do: "Manual estimate"

  defp exercise_name(exercise_id, exercise_options) do
    exercise_id = to_string(exercise_id)

    exercise_options
    |> Enum.find_value("Manual estimate", fn {name, id} ->
      if to_string(id) == exercise_id, do: name
    end)
  end

  defp percentage_rows(one_rep_max) do
    [
      {95, "Heavy singles"},
      {90, "Strength triples"},
      {85, "Strength volume"},
      {80, "Heavy hypertrophy"},
      {75, "Hypertrophy"},
      {70, "Technique volume"},
      {60, "Speed or warm-up"}
    ]
    |> Enum.map(fn {percent, use} ->
      load =
        one_rep_max
        |> Decimal.mult(Decimal.new(percent))
        |> Decimal.div(Decimal.new(100))
        |> Decimal.round(1)
        |> Decimal.normalize()
        |> Decimal.to_string(:normal)

      %{percent: percent, load: load, use: use}
    end)
  end

  defp strength_standard(_one_rep_max, nil), do: "Add bodyweight"

  defp strength_standard(one_rep_max, bodyweight) do
    ratio = Decimal.div(one_rep_max, bodyweight)

    cond do
      Decimal.compare(ratio, Decimal.new("2.0")) in [:gt, :eq] -> "Elite"
      Decimal.compare(ratio, Decimal.new("1.5")) in [:gt, :eq] -> "Advanced"
      Decimal.compare(ratio, Decimal.new("1.0")) in [:gt, :eq] -> "Intermediate"
      Decimal.compare(ratio, Decimal.new("0.75")) in [:gt, :eq] -> "Novice"
      true -> "Beginner"
    end
  end
end
