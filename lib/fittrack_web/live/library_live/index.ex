defmodule FittrackWeb.LibraryLive.Index do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @filter_keys ~w(search muscle_group equipment category difficulty page)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div class="max-w-3xl">
            <p class="text-sm font-semibold uppercase tracking-wide text-primary">Exercise Library</p>
            <h1 class="mt-2 text-3xl font-semibold text-base-content sm:text-4xl">
              Find the right movement fast.
            </h1>
            <p class="mt-3 text-base text-base-content/70">
              Search by name or alias, then narrow by muscle, equipment, category, and difficulty.
            </p>
          </div>
          <%= if @current_scope && @current_scope.user do %>
            <.link
              navigate={~p"/my-exercises"}
              class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-user-circle" class="h-4 w-4" /> My Exercises
            </.link>
          <% end %>
        </div>

        <div class="rounded-2xl border border-base-200 bg-base-100 p-4 shadow-sm sm:p-5">
          <.form for={@form} id="exercise-library-filters-form" phx-change="filter">
            <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
              <.input
                field={@form[:search]}
                type="search"
                label="Search"
                placeholder="bench, bb bench, benh press"
                phx-debounce="300"
              />
              <.input
                field={@form[:muscle_group]}
                type="select"
                label="Muscle"
                options={option_pairs("All muscles", @filter_options.muscles)}
              />
              <.input
                field={@form[:equipment]}
                type="select"
                label="Equipment"
                options={option_pairs("All equipment", @filter_options.equipment)}
              />
              <.input
                field={@form[:category]}
                type="select"
                label="Category"
                options={option_pairs("All categories", @filter_options.categories)}
              />
              <.input
                field={@form[:difficulty]}
                type="select"
                label="Difficulty"
                options={option_pairs("All levels", @filter_options.difficulties)}
              />
            </div>
          </.form>
        </div>

        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <p id="exercise-library-count" class="text-sm text-base-content/70">
            Showing {@pagination_count_label}
          </p>
          <.link
            :if={filters_active?(@filters)}
            patch={~p"/exercises"}
            class="inline-flex items-center gap-2 text-sm font-semibold text-primary transition hover:text-primary/80"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" /> Clear filters
          </.link>
        </div>

        <div
          id="exercise-library-results"
          phx-update="stream"
          class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
        >
          <div
            id="exercise-library-empty-state"
            class="hidden only:block rounded-2xl border border-dashed border-base-300 bg-base-100 p-10 text-center"
          >
            <.icon name="hero-magnifying-glass" class="mx-auto h-10 w-10 text-base-content/30" />
            <h2 class="mt-3 text-base font-semibold text-base-content">No exercises found</h2>
            <p class="mt-1 text-sm text-base-content/70">Try a broader search or fewer filters.</p>
          </div>
          <.exercise_card
            :for={{id, template} <- @streams.templates}
            id={id}
            template={template}
            signed_in?={@current_scope && @current_scope.user}
          />
        </div>

        <nav
          id="exercise-library-pagination"
          class="flex flex-col gap-3 border-t border-base-200 pt-5 sm:flex-row sm:items-center sm:justify-between"
        >
          <p class="text-sm text-base-content/60">
            Page {@pagination.page} of {@pagination.total_pages}
          </p>
          <div class="flex items-center gap-2">
            <.link
              patch={pagination_path(@filters, @pagination.page - 1)}
              class={[
                "inline-flex items-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold transition",
                @pagination.page == 1 && "pointer-events-none opacity-40",
                @pagination.page > 1 && "hover:border-primary hover:text-primary"
              ]}
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" /> Previous
            </.link>
            <.link
              patch={pagination_path(@filters, @pagination.page + 1)}
              class={[
                "inline-flex items-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold transition",
                @pagination.page == @pagination.total_pages && "pointer-events-none opacity-40",
                @pagination.page < @pagination.total_pages &&
                  "hover:border-primary hover:text-primary"
              ]}
            >
              Next <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </div>
        </nav>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Exercise Library")
     |> assign(:filter_options, Training.exercise_template_filter_options())
     |> stream(:templates, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = normalize_filters(params)
    page = parse_page(Map.get(filters, "page"))

    results =
      Training.paginate_exercise_templates(%{
        search: filters["search"],
        muscle_group: filters["muscle_group"],
        equipment: filters["equipment"],
        category: filters["category"],
        difficulty: filters["difficulty"],
        page: page,
        per_page: 24
      })

    filters = Map.put(filters, "page", Integer.to_string(results.page))

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:form, to_form(filters, as: :filters))
     |> assign(:pagination, Map.drop(results, [:entries]))
     |> assign(:pagination_count_label, pagination_count_label(results))
     |> stream(:templates, results.entries, reset: true)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    filters =
      filters
      |> normalize_filters()
      |> Map.put("page", "1")

    {:noreply, push_patch(socket, to: filters_path(filters))}
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

  attr :id, :string, required: true
  attr :template, :map, required: true
  attr :signed_in?, :boolean, required: true

  defp exercise_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="group flex h-full flex-col overflow-hidden rounded-2xl border border-base-200 bg-base-100 shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md"
    >
      <.link navigate={~p"/exercises/#{@template.slug}"} class="block">
        <div class="aspect-[16/10] bg-base-200">
          <%= if media_url = exercise_media_url(@template) do %>
            <img
              src={media_url}
              alt={"#{@template.name} exercise reference"}
              class="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
              loading="lazy"
            />
          <% else %>
            <div
              id={"exercise-card-media-placeholder-#{@template.id}"}
              data-media-placeholder="true"
              class="flex h-full items-center justify-center bg-gradient-to-br from-base-200 to-base-300"
            >
              <.icon name="hero-bolt" class="h-10 w-10 text-base-content/25" />
            </div>
          <% end %>
        </div>
      </.link>
      <div class="flex flex-1 flex-col space-y-4 p-5">
        <div>
          <.link
            navigate={~p"/exercises/#{@template.slug}"}
            class="text-lg font-semibold text-base-content transition group-hover:text-primary"
          >
            {@template.name}
          </.link>
          <p class="mt-1 text-sm text-base-content/65">{summary_line(@template)}</p>
        </div>
        <div class="flex flex-wrap gap-2">
          <.tag :for={label <- Enum.take(muscle_names(@template), 3)} label={label} />
          <.tag
            :if={@template.difficulty}
            label={String.capitalize(@template.difficulty)}
            tone="level"
          />
        </div>
        <div class="mt-auto flex flex-col gap-3 pt-1 sm:flex-row sm:items-center sm:justify-between">
          <.link
            navigate={~p"/exercises/#{@template.slug}"}
            class="inline-flex items-center gap-2 text-sm font-semibold text-primary transition hover:text-primary/80"
          >
            Details <.icon name="hero-arrow-right" class="h-4 w-4" />
          </.link>
          <button
            :if={@signed_in?}
            id={"add-template-#{@template.id}"}
            phx-click="add_to_library"
            phx-value-template_id={@template.id}
            class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-3 py-1.5 text-xs font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
          >
            <.icon name="hero-plus" class="h-3.5 w-3.5" /> Add
          </button>
        </div>
      </div>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "default"

  defp tag(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold",
      @tone == "level" && "bg-primary/10 text-primary",
      @tone == "default" && "bg-base-200 text-base-content/70"
    ]}>
      {@label}
    </span>
    """
  end

  defp normalize_filters(filters) do
    Map.new(@filter_keys, fn key ->
      value =
        filters
        |> Map.get(key, "")
        |> normalize_filter_value()

      {key, value}
    end)
  end

  defp normalize_filter_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_filter_value(_value), do: ""

  defp parse_page(value) do
    case Integer.parse(to_string(value || "1")) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp filters_path(filters) do
    query_params =
      filters
      |> Enum.reject(fn {_key, value} -> value in [nil, "", "1"] end)
      |> Map.new()

    if query_params == %{}, do: ~p"/exercises", else: ~p"/exercises?#{query_params}"
  end

  defp pagination_path(filters, page) when page < 1, do: pagination_path(filters, 1)

  defp pagination_path(filters, page) do
    filters
    |> Map.put("page", Integer.to_string(page))
    |> filters_path()
  end

  defp filters_active?(filters) do
    Enum.any?(filters, fn
      {"page", _value} -> false
      {_key, value} -> value not in [nil, ""]
    end)
  end

  defp option_pairs(default_label, values) do
    [{default_label, ""} | Enum.map(values, &{option_label(&1), &1})]
  end

  defp option_label(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp pagination_count_label(%{total_count: 0}), do: "0 exercises"

  defp pagination_count_label(%{page: page, per_page: per_page, total_count: total_count}) do
    first = (page - 1) * per_page + 1
    last = min(page * per_page, total_count)
    "#{first}-#{last} of #{total_count} exercises"
  end

  defp summary_line(template) do
    [
      template.exercise_category,
      List.first(muscle_names(template)),
      List.first(equipment_names(template))
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&option_label/1)
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
end
