defmodule FittrackWeb.Admin.ExerciseLibraryLive do
  use FittrackWeb, :live_view

  alias Fittrack.Training

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-base-content/50">
              Internal
            </p>
            <h1 class="mt-2 text-3xl font-semibold text-base-content">Exercise Admin</h1>
            <p class="mt-2 max-w-2xl text-sm text-base-content/70">
              Catalog quality, normalized taxonomy coverage, and recent imports.
            </p>
          </div>
          <.link
            id="admin-exercise-library-link"
            navigate={~p"/library"}
            class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-book-open" class="h-4 w-4" /> Public library
          </.link>
        </div>

        <section id="exercise-admin-metrics" class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          <.metric label="Templates" value={@summary.templates} icon="hero-squares-2x2" />
          <.metric label="Muscles" value={@summary.muscles} icon="hero-bolt" />
          <.metric label="Equipment" value={@summary.equipment} icon="hero-wrench-screwdriver" />
          <.metric label="Media" value={@summary.media} icon="hero-photo" />
          <.metric label="Sources" value={@summary.sources} icon="hero-link" />
        </section>

        <section class="grid gap-4 lg:grid-cols-3">
          <.quality_panel
            id="missing-primary-muscle"
            label="Missing muscle"
            value={@summary.missing_primary_muscle}
            icon="hero-exclamation-triangle"
          />
          <.quality_panel
            id="missing-equipment"
            label="Missing equipment"
            value={@summary.missing_equipment}
            icon="hero-exclamation-triangle"
          />
          <.quality_panel
            id="missing-media"
            label="Missing media"
            value={@summary.missing_media}
            icon="hero-photo"
          />
        </section>

        <section class="rounded-xl border border-base-200 bg-base-100 shadow-sm">
          <div class="flex flex-col gap-2 border-b border-base-200 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 class="text-base font-semibold text-base-content">Recent Templates</h2>
              <p class="text-sm text-base-content/60">
                Latest records with normalized muscle, equipment, source, and media links.
              </p>
            </div>
            <div class="flex gap-2 text-xs font-semibold text-base-content/60">
              <span>{@summary.normalized_muscle_links} muscle links</span>
              <span>•</span>
              <span>{@summary.normalized_equipment_links} equipment links</span>
            </div>
          </div>

          <div id="admin-exercise-template-list" class="divide-y divide-base-200">
            <div
              :for={template <- @recent_templates}
              id={"admin-exercise-template-#{template.id}"}
              class="grid gap-4 px-5 py-4 lg:grid-cols-[1.5fr_1fr_1fr]"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <.link
                    navigate={~p"/library/#{template}"}
                    class="font-semibold text-base-content transition hover:text-primary"
                  >
                    {template.name}
                  </.link>
                  <span
                    :if={template.source_id}
                    class="rounded-full bg-base-200 px-2 py-0.5 text-xs font-semibold text-base-content/60"
                  >
                    wger:{template.source_id}
                  </span>
                </div>
                <p class="mt-1 line-clamp-2 text-sm text-base-content/60">
                  {template.notes || "No notes imported yet."}
                </p>
              </div>

              <div class="flex flex-wrap content-start gap-2">
                <span
                  :for={template_muscle <- template.template_muscles}
                  class={[
                    "rounded-full px-2.5 py-1 text-xs font-semibold",
                    if(template_muscle.role == "primary",
                      do: "bg-primary/10 text-primary",
                      else: "bg-base-200 text-base-content/70"
                    )
                  ]}
                >
                  {template_muscle.exercise_muscle.name}
                </span>
                <span
                  :if={template.template_muscles == []}
                  class="text-sm text-base-content/50"
                >
                  No normalized muscles
                </span>
              </div>

              <div class="flex flex-wrap content-start gap-2">
                <span
                  :for={template_equipment <- template.template_equipment}
                  class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70"
                >
                  {template_equipment.exercise_equipment.name}
                </span>
                <span
                  :if={template.media != []}
                  class="rounded-full bg-success/10 px-2.5 py-1 text-xs font-semibold text-success"
                >
                  media
                </span>
                <span
                  :for={
                    media <- Enum.filter(template.media, &(&1.provider_attribution not in [nil, ""]))
                  }
                  class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70"
                >
                  {media.provider_attribution}
                </span>
                <span
                  :if={template.template_equipment == []}
                  class="text-sm text-base-content/50"
                >
                  No normalized equipment
                </span>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Exercise Admin")
     |> assign(:summary, Training.exercise_library_admin_summary())
     |> assign(:recent_templates, Training.list_recent_exercise_templates())}
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true

  defp metric(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-200 bg-base-100 p-5 shadow-sm">
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-medium text-base-content/60">{@label}</p>
        <.icon name={@icon} class="h-5 w-5 text-primary" />
      </div>
      <p class="mt-3 text-3xl font-semibold text-base-content">{@value}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true

  defp quality_panel(assigns) do
    ~H"""
    <div id={@id} class="rounded-xl border border-base-200 bg-base-100 p-5 shadow-sm">
      <div class="flex items-center justify-between gap-3">
        <div>
          <p class="text-sm font-semibold text-base-content">{@label}</p>
          <p class="mt-1 text-xs text-base-content/60">Needs importer or manual cleanup</p>
        </div>
        <.icon name={@icon} class="h-5 w-5 text-warning" />
      </div>
      <p class="mt-4 text-2xl font-semibold text-base-content">{@value}</p>
    </div>
    """
  end
end
