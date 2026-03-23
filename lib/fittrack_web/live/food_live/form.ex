defmodule FittrackWeb.FoodLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.Food

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:actions>
          <.link navigate={~p"/foods"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" /> Back
          </.link>
        </:actions>
      </.header>

      <.form for={@form} id="food-form" phx-change="validate" phx-submit="save">
        <div class="grid gap-4 md:grid-cols-2">
          <.input field={@form[:name]} type="text" label="Food Name" required />
          <.input field={@form[:unit]} type="text" label="Unit (e.g., g, ml, cup)" required />
          <.input
            field={@form[:unit_amount]}
            type="number"
            label="Amount per Unit"
            step="0.1"
            required
          />
          <.input
            field={@form[:calories_per_unit]}
            type="number"
            label="Calories per Unit"
            step="0.1"
            required
          />
          <.input
            field={@form[:protein_per_unit]}
            type="number"
            label="Protein (g) per Unit"
            step="0.1"
          />
          <.input field={@form[:carbs_per_unit]} type="number" label="Carbs (g) per Unit" step="0.1" />
          <.input field={@form[:fats_per_unit]} type="number" label="Fats (g) per Unit" step="0.1" />
        </div>

        <div class="mt-6 flex justify-end gap-2">
          <.button navigate={~p"/foods"} class="btn btn-ghost">Cancel</.button>
          <.button phx-disable-with="Saving..." class="btn btn-primary">
            {@live_action == :new && "Create Food"}
            {@live_action == :edit && "Update Food"}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    food = %Food{}
    changeset = Nutrition.change_food(food)

    socket
    |> assign(:page_title, "Add Food")
    |> assign(:food, food)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    food = Nutrition.get_food!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Food")
    |> assign(:food, food)
    |> assign(:form, to_form(Nutrition.change_food(food)))
  end

  @impl true
  def handle_event("validate", %{"food" => food_params}, socket) do
    changeset =
      socket.assigns.food
      |> Nutrition.change_food(food_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"food" => food_params}, socket) do
    case socket.assigns.live_action do
      :new ->
        case Nutrition.create_food(socket.assigns.current_scope, food_params) do
          {:ok, _food} ->
            {:noreply,
             socket
             |> put_flash(:info, "Food created successfully")
             |> push_navigate(to: ~p"/foods")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      :edit ->
        case Nutrition.update_food(socket.assigns.current_scope, socket.assigns.food, food_params) do
          {:ok, _food} ->
            {:noreply,
             socket
             |> put_flash(:info, "Food updated successfully")
             |> push_navigate(to: ~p"/foods")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end
end
