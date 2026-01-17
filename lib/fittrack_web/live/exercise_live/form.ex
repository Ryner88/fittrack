defmodule FittrackWeb.ExerciseLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Training
  alias Fittrack.Training.Exercise

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage exercise records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="exercise-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:primary_muscle]} type="text" label="Primary muscle" />
        <.input field={@form[:equipment]} type="text" label="Equipment" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Exercise</.button>
          <.button navigate={return_path(@return_to, @exercise)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    exercise = Training.get_exercise!(id)

    socket
    |> assign(:page_title, "Edit Exercise")
    |> assign(:exercise, exercise)
    |> assign(:form, to_form(Training.change_exercise(exercise)))
  end

  defp apply_action(socket, :new, _params) do
    exercise = %Exercise{}

    socket
    |> assign(:page_title, "New Exercise")
    |> assign(:exercise, exercise)
    |> assign(:form, to_form(Training.change_exercise(exercise)))
  end

  @impl true
  def handle_event("validate", %{"exercise" => exercise_params}, socket) do
    changeset = Training.change_exercise(socket.assigns.exercise, exercise_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"exercise" => exercise_params}, socket) do
    save_exercise(socket, socket.assigns.live_action, exercise_params)
  end

  defp save_exercise(socket, :edit, exercise_params) do
    case Training.update_exercise(socket.assigns.exercise, exercise_params) do
      {:ok, exercise} ->
        {:noreply,
         socket
         |> put_flash(:info, "Exercise updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, exercise))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_exercise(socket, :new, exercise_params) do
    case Training.create_exercise(exercise_params) do
      {:ok, exercise} ->
        {:noreply,
         socket
         |> put_flash(:info, "Exercise created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, exercise))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _exercise), do: ~p"/exercises"
  defp return_path("show", exercise), do: ~p"/exercises/#{exercise}"
end
