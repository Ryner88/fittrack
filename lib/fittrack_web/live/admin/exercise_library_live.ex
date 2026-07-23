defmodule FittrackWeb.Admin.ExerciseLibraryLive do
  use FittrackWeb, :live_view

  alias Fittrack.Training
  alias Fittrack.Training.ExerciseTemplate

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
              Manage shared exercise templates, normalized taxonomy, source metadata, and media quality.
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.link
              id="admin-exercise-new-link"
              navigate={~p"/admin/exercises/new"}
              class="inline-flex items-center justify-center gap-2 rounded-full bg-primary px-4 py-2 text-sm font-semibold text-primary-content transition hover:bg-primary/90"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> New template
            </.link>
            <.link
              id="admin-exercise-media-link"
              navigate={~p"/admin/exercises/media"}
              class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-chart-bar-square" class="h-4 w-4" /> Media health
            </.link>
            <.link
              id="admin-exercise-library-link"
              navigate={~p"/exercises"}
              class="inline-flex items-center justify-center gap-2 rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-book-open" class="h-4 w-4" /> Public library
            </.link>
          </div>
        </div>

        <.metrics summary={@summary} />

        <%= case @live_action do %>
          <% :index -> %>
            <.index_view
              page={@page}
              filters={@filters}
              filter_form={@filter_form}
              filter_options={@filter_options}
            />
          <% :media -> %>
            <.media_report_view
              media_page={@media_page}
              media_filters={@media_filters}
              media_filter_form={@media_filter_form}
              media_filter_options={@media_filter_options}
            />
          <% action when action in [:new, :edit] -> %>
            <.form_view
              action={@live_action}
              form={@form}
              template={@template}
              form_title={@form_title}
            />
          <% :show -> %>
            <.show_view template={@template} archive_form={@archive_form} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :summary, :map, required: true

  defp metrics(assigns) do
    ~H"""
    <div class="space-y-4">
      <section id="exercise-admin-metrics" class="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <.metric label="Templates" value={@summary.templates} icon="hero-squares-2x2" />
        <.metric label="Muscles" value={@summary.muscles} icon="hero-bolt" />
        <.metric label="Equipment" value={@summary.equipment} icon="hero-wrench-screwdriver" />
        <.metric label="Media" value={@summary.media} icon="hero-photo" />
        <.metric label="Sources" value={@summary.sources} icon="hero-link" />
      </section>

      <section id="exercise-media-status-metrics" class="grid gap-4 md:grid-cols-3 xl:grid-cols-6">
        <.quality_panel
          id="cached-media"
          label="Cached"
          value={@summary.cached_media}
          icon="hero-check-circle"
        />
        <.quality_panel
          id="missing-media-records"
          label="Missing URL"
          value={@summary.missing_media_records}
          icon="hero-link-slash"
        />
        <.quality_panel
          id="skipped-media"
          label="Skipped"
          value={@summary.skipped_media}
          icon="hero-no-symbol"
        />
        <.quality_panel
          id="stale-media"
          label="Stale"
          value={@summary.stale_media}
          icon="hero-exclamation-triangle"
        />
        <.quality_panel
          id="failed-media"
          label="Failed"
          value={@summary.failed_media}
          icon="hero-x-circle"
        />
        <.quality_panel
          id="unsupported-media"
          label="Unsupported"
          value={@summary.unsupported_media}
          icon="hero-shield-exclamation"
        />
      </section>
    </div>
    """
  end

  attr :page, :map, required: true
  attr :filters, :map, required: true
  attr :filter_form, :map, required: true
  attr :filter_options, :map, required: true

  defp index_view(assigns) do
    ~H"""
    <section class="rounded-xl border border-base-200 bg-base-100 shadow-sm">
      <div class="border-b border-base-200 px-5 py-4">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 class="text-base font-semibold text-base-content">Shared Templates</h2>
            <p class="text-sm text-base-content/60">
              Search name, slug, alias, source, tag, muscle, equipment, and media status.
            </p>
          </div>
          <p id="admin-exercise-template-count" class="text-sm font-semibold text-base-content/60">
            {@page.total_count} templates
          </p>
        </div>

        <.form
          for={@filter_form}
          id="admin-template-filter-form"
          phx-change="filter"
          phx-submit="filter"
          class="mt-4 grid gap-3 lg:grid-cols-6"
        >
          <.input
            field={@filter_form[:search]}
            type="search"
            label="Search"
            placeholder="Name, slug, alias, source, tag"
          />
          <.input
            field={@filter_form[:muscle_group]}
            type="select"
            label="Muscle"
            prompt="Any"
            options={@filter_options.muscles}
          />
          <.input
            field={@filter_form[:equipment]}
            type="select"
            label="Equipment"
            prompt="Any"
            options={@filter_options.equipment}
          />
          <.input
            field={@filter_form[:source]}
            type="select"
            label="Source"
            prompt="Any"
            options={@filter_options.sources}
          />
          <.input
            field={@filter_form[:tag]}
            type="select"
            label="Tag"
            prompt="Any"
            options={@filter_options.tags}
          />
          <.input
            field={@filter_form[:media_status]}
            type="select"
            label="Media"
            prompt="Any"
            options={@filter_options.media_statuses}
          />
          <.input
            field={@filter_form[:review_status]}
            type="select"
            label="Review"
            prompt="Any"
            options={@filter_options.review_statuses}
          />
          <.input
            field={@filter_form[:category]}
            type="select"
            label="Category"
            prompt="Any"
            options={@filter_options.categories}
          />
          <.input
            field={@filter_form[:difficulty]}
            type="select"
            label="Difficulty"
            prompt="Any"
            options={@filter_options.difficulties}
          />
          <div class="flex items-end gap-2">
            <button
              id="admin-template-search-submit"
              type="submit"
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2 text-sm font-semibold text-base-100 transition hover:bg-base-content/85"
            >
              <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Search
            </button>
          </div>
        </.form>
      </div>

      <div id="admin-exercise-template-list" class="divide-y divide-base-200">
        <div
          :for={template <- @page.entries}
          id={"admin-exercise-template-#{template.id}"}
          class="grid gap-4 px-5 py-4 xl:grid-cols-[1.25fr_1fr_1fr_0.75fr]"
        >
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <.link
                navigate={~p"/admin/exercises/#{template.id}"}
                class="font-semibold text-base-content transition hover:text-primary"
              >
                {template.name}
              </.link>
              <span
                :if={template.is_verified}
                class="rounded-full bg-success/10 px-2 py-0.5 text-xs font-semibold text-success"
              >
                verified
              </span>
              <span
                :if={template.is_deprecated}
                class="rounded-full bg-warning/10 px-2 py-0.5 text-xs font-semibold text-warning"
              >
                archived
              </span>
            </div>
            <p class="mt-1 text-xs text-base-content/50">{template.slug}</p>
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
            <span :if={template.template_muscles == []} class="text-sm text-base-content/50">
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
            <span :if={template.template_equipment == []} class="text-sm text-base-content/50">
              No normalized equipment
            </span>
          </div>

          <div class="flex flex-wrap content-start justify-start gap-2 xl:justify-end">
            <span
              :for={status <- media_statuses(template)}
              class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70"
            >
              {status}
            </span>
            <.link
              id={"admin-exercise-template-edit-#{template.id}"}
              navigate={~p"/admin/exercises/#{template.id}/edit"}
              class="inline-flex items-center gap-1 rounded-full border border-base-300 px-2.5 py-1 text-xs font-semibold transition hover:border-primary hover:text-primary"
            >
              <.icon name="hero-pencil-square" class="h-3.5 w-3.5" /> Edit
            </.link>
          </div>
        </div>

        <div
          :if={@page.entries == []}
          id="admin-exercise-template-empty"
          class="px-5 py-12 text-center text-sm text-base-content/60"
        >
          No templates match those filters.
        </div>
      </div>
    </section>
    """
  end

  attr :media_page, :map, required: true
  attr :media_filters, :map, required: true
  attr :media_filter_form, :map, required: true
  attr :media_filter_options, :map, required: true

  defp media_report_view(assigns) do
    ~H"""
    <section
      id="admin-exercise-media-report"
      class="rounded-xl border border-base-200 bg-base-100 shadow-sm"
    >
      <div class="border-b border-base-200 px-5 py-4">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 class="text-base font-semibold text-base-content">Media Health</h2>
            <p class="text-sm text-base-content/60">
              Inspect cached files, source URLs, status reasons, and timestamps for cleanup.
            </p>
          </div>
          <p id="admin-exercise-media-count" class="text-sm font-semibold text-base-content/60">
            {@media_page.total_count} media records
          </p>
        </div>

        <.form
          for={@media_filter_form}
          id="admin-media-filter-form"
          phx-change="media_filter"
          phx-submit="media_filter"
          class="mt-4 grid gap-3 lg:grid-cols-[1fr_12rem_12rem_auto]"
        >
          <.input
            field={@media_filter_form[:search]}
            type="search"
            label="Search"
            placeholder="Exercise, source URL, cached path"
          />
          <.input
            field={@media_filter_form[:status]}
            type="select"
            label="Status"
            prompt="Any"
            options={@media_filter_options.statuses}
          />
          <.input
            field={@media_filter_form[:source]}
            type="select"
            label="Source"
            prompt="Any"
            options={@media_filter_options.sources}
          />
          <div class="flex items-end">
            <button
              id="admin-media-search-submit"
              type="submit"
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-base-content px-4 py-2 text-sm font-semibold text-base-100 transition hover:bg-base-content/85"
            >
              <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Search
            </button>
          </div>
        </.form>
      </div>

      <div id="admin-exercise-media-list" class="divide-y divide-base-200">
        <div
          :for={media <- @media_page.entries}
          id={"admin-exercise-media-#{media.id}"}
          class="grid gap-4 px-5 py-4 xl:grid-cols-[1fr_0.75fr_1.2fr_1fr]"
        >
          <div class="min-w-0">
            <.link
              navigate={~p"/admin/exercises/#{media.exercise_template_id}"}
              class="font-semibold text-base-content transition hover:text-primary"
            >
              {media.exercise_template.name}
            </.link>
            <div class="mt-2 flex flex-wrap gap-2">
              <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70">
                {status_label(media.cache_status)}
              </span>
              <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70">
                {media.kind}
              </span>
              <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70">
                {media.source || "unknown"}
              </span>
            </div>
          </div>

          <dl class="grid gap-2 text-xs text-base-content/70">
            <div>
              <dt class="font-semibold text-base-content">Source ID</dt>
              <dd>{media.source_id || media.source_exercise_id || "None"}</dd>
            </div>
            <div>
              <dt class="font-semibold text-base-content">Checked</dt>
              <dd>{format_datetime(media.checked_at)}</dd>
            </div>
            <div>
              <dt class="font-semibold text-base-content">Fetched</dt>
              <dd>{format_datetime(media.cached_at)}</dd>
            </div>
          </dl>

          <dl class="grid gap-2 text-xs text-base-content/70">
            <div>
              <dt class="font-semibold text-base-content">Source URL</dt>
              <dd class="break-all">{media.source_url || "None"}</dd>
            </div>
            <div>
              <dt class="font-semibold text-base-content">Cached path / key</dt>
              <dd class="break-all">{media_cache_path(media)}</dd>
            </div>
          </dl>

          <dl class="grid gap-2 text-xs text-base-content/70">
            <div>
              <dt class="font-semibold text-base-content">Reason</dt>
              <dd>{media.failure_reason || "None"}</dd>
            </div>
            <div>
              <dt class="font-semibold text-base-content">Size / type</dt>
              <dd>{media_size_label(media)} / {media.mime_type || "unknown"}</dd>
            </div>
          </dl>
        </div>

        <div
          :if={@media_page.entries == []}
          id="admin-exercise-media-empty"
          class="px-5 py-12 text-center text-sm text-base-content/60"
        >
          No media records match those filters.
        </div>
      </div>
    </section>
    """
  end

  attr :action, :atom, required: true
  attr :form, :map, required: true
  attr :template, ExerciseTemplate, required: true
  attr :form_title, :string, required: true

  defp form_view(assigns) do
    ~H"""
    <section class="rounded-xl border border-base-200 bg-base-100 shadow-sm">
      <div class="flex items-center justify-between border-b border-base-200 px-5 py-4">
        <div>
          <h2 class="text-base font-semibold text-base-content">{@form_title}</h2>
          <p class="text-sm text-base-content/60">
            Core template fields, aliases, tags, source metadata, and normalized taxonomy links.
          </p>
        </div>
        <.link
          navigate={~p"/admin/exercises"}
          class="text-sm font-semibold text-base-content/60 transition hover:text-primary"
        >
          Back to list
        </.link>
      </div>

      <.form for={@form} id="admin-template-form" phx-submit="save" class="grid gap-6 p-5">
        <div class="grid gap-4 lg:grid-cols-3">
          <.input field={@form[:name]} type="text" label="Name" required />
          <.input field={@form[:slug]} type="text" label="Slug" />
          <.input field={@form[:source_id]} type="number" label="Legacy source ID" />
          <.input field={@form[:primary_muscle]} type="text" label="Primary muscle" />
          <.input field={@form[:equipment]} type="text" label="Equipment" />
          <.input
            field={@form[:difficulty]}
            type="select"
            label="Difficulty"
            prompt="Choose"
            options={["beginner", "intermediate", "advanced"]}
          />
          <.input
            field={@form[:movement_pattern]}
            type="select"
            label="Movement pattern"
            prompt="Choose"
            options={~w(push pull squat hinge lunge carry rotation core isolation)}
          />
          <.input
            field={@form[:exercise_category]}
            type="select"
            label="Category"
            prompt="Choose"
            options={~w(compound isolation bodyweight machine cardio mobility plyometric accessory)}
          />
          <.input
            field={@form[:movement_direction]}
            type="select"
            label="Direction"
            prompt="Choose"
            options={
              ~w(horizontal_push vertical_push horizontal_pull vertical_pull squat hinge lunge carry rotation anti_rotation flexion extension)
            }
          />
          <.input field={@form[:quality_score]} type="number" label="Quality score" min="0" max="100" />
          <.input field={@form[:fatigue_score]} type="number" label="Fatigue score" min="0" max="10" />
          <.input
            field={@form[:skill_requirement]}
            type="select"
            label="Skill"
            prompt="Choose"
            options={~w(low moderate high)}
          />
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <.input field={@form[:notes]} type="textarea" label="Notes" rows="5" />
          <div class="grid gap-3">
            <.input field={@form[:image_url]} type="url" label="Image URL" />
            <.input
              field={@form[:aliases_text]}
              type="textarea"
              label="Aliases"
              rows="3"
              placeholder="One per line or comma separated"
            />
            <.input
              field={@form[:weighted_tags]}
              type="text"
              label="Weighted tags"
              placeholder="horizontal_push, chest"
            />
            <.input
              field={@form[:training_style_tags]}
              type="text"
              label="Training style tags"
              placeholder="strength, hypertrophy"
            />
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <.input field={@form[:secondary_muscles]} type="text" label="Legacy secondary muscles" />
          <.input
            field={@form[:muscle_names]}
            type="textarea"
            label="Normalized muscles"
            rows="3"
            placeholder="Primary first, then secondary muscles"
          />
          <.input
            field={@form[:equipment_names]}
            type="textarea"
            label="Normalized equipment"
            rows="3"
            placeholder="One per line or comma separated"
          />
          <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
            <.input field={@form[:is_verified]} type="checkbox" label="Verified" />
            <.input field={@form[:is_ai_generated]} type="checkbox" label="AI generated" />
            <.input field={@form[:is_deprecated]} type="checkbox" label="Archived" />
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <div class="grid gap-3">
            <.input
              field={@form[:source_name]}
              type="text"
              label="Source name"
              placeholder="wger, admin, vendor"
            />
            <.input field={@form[:source_external_id]} type="text" label="Source external ID" />
            <.input field={@form[:source_url]} type="url" label="Source URL" />
          </div>
          <.input
            field={@form[:source_payload]}
            type="textarea"
            label="Source payload summary or JSON"
            rows="6"
          />
        </div>

        <div class="flex justify-end gap-2 border-t border-base-200 pt-5">
          <.link
            navigate={template_back_path(@template)}
            class="rounded-lg border border-base-300 px-4 py-2 text-sm font-semibold transition hover:border-primary hover:text-primary"
          >
            Cancel
          </.link>
          <button
            id="admin-template-save"
            type="submit"
            class="inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-content transition hover:bg-primary/90"
          >
            <.icon name="hero-check" class="h-4 w-4" /> Save template
          </button>
        </div>
      </.form>
    </section>
    """
  end

  attr :template, ExerciseTemplate, required: true
  attr :archive_form, :map, required: true

  defp show_view(assigns) do
    ~H"""
    <div class="grid gap-6 xl:grid-cols-[1fr_360px]">
      <section
        id="admin-template-review"
        class="rounded-xl border border-base-200 bg-base-100 shadow-sm"
      >
        <div class="flex flex-col gap-3 border-b border-base-200 px-5 py-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="text-xl font-semibold text-base-content">{@template.name}</h2>
              <span
                :if={@template.is_verified}
                class="rounded-full bg-success/10 px-2 py-0.5 text-xs font-semibold text-success"
              >
                verified
              </span>
              <span
                :if={@template.is_deprecated}
                class="rounded-full bg-warning/10 px-2 py-0.5 text-xs font-semibold text-warning"
              >
                archived
              </span>
            </div>
            <p class="mt-1 text-sm text-base-content/60">{@template.slug}</p>
          </div>
          <div class="flex gap-2">
            <.link
              navigate={~p"/admin/exercises/#{@template.id}/edit"}
              class="inline-flex items-center gap-2 rounded-lg bg-primary px-3 py-2 text-sm font-semibold text-primary-content transition hover:bg-primary/90"
            >
              <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit
            </.link>
            <.link
              navigate={~p"/admin/exercises"}
              class="rounded-lg border border-base-300 px-3 py-2 text-sm font-semibold transition hover:border-primary hover:text-primary"
            >
              Back
            </.link>
          </div>
        </div>

        <div class="grid gap-6 p-5">
          <.review_block title="Template Quality">
            <div class="grid gap-3 sm:grid-cols-3">
              <.review_stat label="Quality" value={@template.quality_score || 0} />
              <.review_stat label="Difficulty" value={@template.difficulty || "Unset"} />
              <.review_stat label="Media" value={Enum.join(media_statuses(@template), ", ")} />
            </div>
            <p class="mt-4 text-sm leading-6 text-base-content/70">
              {@template.notes || "No notes."}
            </p>
          </.review_block>

          <.review_block title="Aliases, Tags, And Taxonomy">
            <div class="grid gap-4 lg:grid-cols-2">
              <.pill_group label="Aliases" values={Enum.map(@template.aliases, & &1.name)} />
              <.pill_group label="Weighted tags" values={@template.weighted_tags || []} />
              <.pill_group
                label="Muscles"
                values={Enum.map(@template.template_muscles, & &1.exercise_muscle.name)}
              />
              <.pill_group
                label="Equipment"
                values={Enum.map(@template.template_equipment, & &1.exercise_equipment.name)}
              />
            </div>
          </.review_block>

          <.review_block title="Relationship Metadata">
            <div id="admin-template-relationships" class="grid gap-3 lg:grid-cols-2">
              <.relationship_review
                title="Variations"
                relationships={@template.variations}
                template_key={:variation_exercise_template}
              />
              <.relationship_review
                title="Substitutions"
                relationships={@template.substitutions}
                template_key={:substitute_exercise_template}
              />
            </div>
          </.review_block>

          <.review_block title="Source Visibility">
            <div id="admin-template-sources" class="grid gap-3">
              <div
                :for={source <- @template.template_sources}
                id={"admin-template-source-#{source.id}"}
                class="rounded-lg border border-base-200 p-4"
              >
                <div class="flex flex-wrap items-center gap-2 text-sm font-semibold">
                  <span>{source.source}</span>
                  <span class="text-base-content/40">/</span>
                  <span>{source.external_id}</span>
                </div>
                <p :if={source.source_url} class="mt-1 text-xs text-base-content/60">
                  {source.source_url}
                </p>
                <p class="mt-2 text-xs text-base-content/60">
                  Payload keys: {payload_summary(source.payload)}
                </p>
              </div>
              <p :if={@template.template_sources == []} class="text-sm text-base-content/60">
                No source metadata recorded.
              </p>
            </div>
          </.review_block>

          <.review_block title="Media Review">
            <div id="admin-template-media" class="grid gap-3">
              <div
                :for={media <- @template.media}
                id={"admin-template-media-#{media.id}"}
                class="rounded-lg border border-base-200 p-4"
              >
                <div class="flex flex-wrap items-center gap-2">
                  <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold">
                    {media.kind}
                  </span>
                  <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold">
                    {media.cache_status}
                  </span>
                  <span
                    :if={media.is_primary}
                    class="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary"
                  >
                    primary
                  </span>
                </div>
                <dl class="mt-3 grid gap-2 text-xs text-base-content/70 sm:grid-cols-2">
                  <div>
                    <dt class="font-semibold">Source</dt>
                    <dd>{media.source || "Unknown"} {media.source_id}</dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Remote</dt>
                    <dd class="break-all">{media.source_url || "None"}</dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Cached path</dt>
                    <dd>{media.local_path || "Not cached"}</dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Failure</dt>
                    <dd>{media.failure_reason || "None"}</dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Attribution</dt>
                    <dd>{media.provider_attribution || "None"}</dd>
                  </div>
                </dl>
              </div>
              <p
                :if={@template.media == []}
                id="admin-template-media-missing"
                class="text-sm text-base-content/60"
              >
                Missing media: no cached or remote media records exist for this template.
              </p>
            </div>
          </.review_block>
        </div>
      </section>

      <aside class="space-y-4">
        <section
          id="admin-template-archive-panel"
          class="rounded-xl border border-warning/30 bg-warning/5 p-5"
        >
          <h3 class="font-semibold text-base-content">Archive Template</h3>
          <p class="mt-2 text-sm text-base-content/70">
            Archive hides this template from admin review queues without deleting workout or user exercise data.
          </p>
          <.form
            for={@archive_form}
            id="admin-template-archive-form"
            phx-submit="archive"
            class="mt-4 space-y-3"
          >
            <.input field={@archive_form[:confirm]} type="text" label="Type ARCHIVE to confirm" />
            <button
              id="admin-template-archive-submit"
              type="submit"
              class="inline-flex w-full items-center justify-center gap-2 rounded-lg bg-warning px-4 py-2 text-sm font-semibold text-warning-content transition hover:bg-warning/90"
              data-confirm="Archive this shared template?"
            >
              <.icon name="hero-archive-box" class="h-4 w-4" /> Archive template
            </button>
          </.form>
        </section>
      </aside>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Exercise Admin")
     |> assign(:summary, Training.exercise_library_admin_summary())
     |> assign(:filter_options, Training.admin_exercise_template_filter_options())
     |> assign(:media_filter_options, Training.admin_exercise_media_filter_options())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/exercises?#{clean_params(filters)}")}
  end

  def handle_event("media_filter", %{"filters" => filters}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/exercises/media?#{clean_params(filters)}")}
  end

  def handle_event("save", %{"template" => template_params}, socket) do
    save_template(socket, socket.assigns.live_action, template_params)
  end

  def handle_event("archive", %{"archive" => %{"confirm" => "ARCHIVE"}}, socket) do
    case Training.archive_exercise_template(socket.assigns.template) do
      {:ok, template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Template archived.")
         |> push_navigate(to: ~p"/admin/exercises/#{template.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Template could not be archived.")}
    end
  end

  def handle_event("archive", _params, socket) do
    {:noreply, put_flash(socket, :error, "Type ARCHIVE to confirm archiving this template.")}
  end

  defp apply_action(socket, :index, params) do
    filters = clean_params(params)
    page = Training.paginate_admin_exercise_templates(filters)

    socket
    |> assign(:page_title, "Exercise Admin")
    |> assign(:filters, filters)
    |> assign(:filter_form, to_form(filters, as: :filters))
    |> assign(:page, page)
  end

  defp apply_action(socket, :media, params) do
    filters = clean_params(params)
    media_page = Training.paginate_admin_exercise_media(filters)

    socket
    |> assign(:page_title, "Exercise Media Health")
    |> assign(:media_filters, filters)
    |> assign(:media_filter_form, to_form(filters, as: :filters))
    |> assign(:media_page, media_page)
  end

  defp apply_action(socket, :new, _params) do
    template = %ExerciseTemplate{}

    socket
    |> assign(:page_title, "New Exercise Template")
    |> assign(:form_title, "New Shared Template")
    |> assign(:template, template)
    |> assign(:form, to_form(template_form_source(template), as: :template))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    template = Training.get_admin_exercise_template!(id)

    socket
    |> assign(:page_title, "Edit #{template.name}")
    |> assign(:form_title, "Edit Shared Template")
    |> assign(:template, template)
    |> assign(:form, to_form(template_form_source(template), as: :template))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    template = Training.get_admin_exercise_template!(id)

    socket
    |> assign(:page_title, template.name)
    |> assign(:template, template)
    |> assign(:archive_form, to_form(%{"confirm" => ""}, as: :archive))
  end

  defp save_template(socket, :new, template_params) do
    case Training.create_exercise_template(template_params) do
      {:ok, template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Template created.")
         |> push_navigate(to: ~p"/admin/exercises/#{template.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Template could not be created.")
         |> assign(
           :form,
           to_form(Map.merge(template_params, errors_for(changeset)), as: :template)
         )}
    end
  end

  defp save_template(socket, :edit, template_params) do
    case Training.update_exercise_template(socket.assigns.template, template_params) do
      {:ok, template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Template updated.")
         |> push_navigate(to: ~p"/admin/exercises/#{template.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Template could not be updated.")
         |> assign(
           :form,
           to_form(Map.merge(template_params, errors_for(changeset)), as: :template)
         )}
    end
  end

  attr :title, :string, required: true
  attr :relationships, :list, required: true
  attr :template_key, :atom, required: true

  defp relationship_review(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-200 p-4">
      <h3 class="text-sm font-semibold text-base-content">{@title}</h3>
      <div class="mt-3 grid gap-3">
        <div
          :for={relationship <- @relationships}
          class="rounded-lg border border-base-200 bg-base-50 p-3 text-xs text-base-content/70"
        >
          <% template = Map.fetch!(relationship, @template_key) %>
          <p class="font-semibold text-base-content">{template.name}</p>
          <p class="mt-1">{relationship_meta(relationship)}</p>
        </div>
        <p :if={@relationships == []} class="text-sm text-base-content/60">None linked.</p>
      </div>
    </section>
    """
  end

  defp relationship_meta(relationship) do
    [
      relationship_kind(relationship),
      metadata_score("Match", relationship.similarity_score),
      metadata_score("Reason", Map.get(relationship, :reason_quality)),
      difficulty_delta_label(relationship.difficulty_delta),
      equipment_requirement_label(relationship.equipment_requirements)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp relationship_kind(%{relationship: relationship}), do: status_label(relationship)
  defp relationship_kind(%{reason: reason}), do: status_label(reason)
  defp relationship_kind(_relationship), do: nil

  defp metadata_score(_label, nil), do: nil
  defp metadata_score(label, score), do: "#{label} #{score}/100"

  defp difficulty_delta_label(nil), do: nil
  defp difficulty_delta_label(0), do: "Same difficulty"
  defp difficulty_delta_label(delta) when delta > 0, do: "+#{delta} difficulty"
  defp difficulty_delta_label(delta), do: "#{delta} difficulty"

  defp equipment_requirement_label([]), do: nil
  defp equipment_requirement_label(nil), do: nil
  defp equipment_requirement_label(equipment), do: "Needs #{Enum.join(equipment, ", ")}"

  defp clean_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp template_form_source(%ExerciseTemplate{} = template) do
    source = List.first(loaded_or_empty(template.template_sources))

    %{
      "name" => template.name,
      "slug" => template.slug,
      "source_id" => template.source_id,
      "primary_muscle" => template.primary_muscle,
      "secondary_muscles" => Enum.join(template.secondary_muscles || [], ", "),
      "equipment" => template.equipment,
      "difficulty" => template.difficulty,
      "image_url" => template.image_url,
      "notes" => template.notes,
      "weighted_tags" => Enum.join(template.weighted_tags || [], ", "),
      "training_style_tags" => Enum.join(template.training_style_tags || [], ", "),
      "is_verified" => template.is_verified,
      "is_ai_generated" => template.is_ai_generated,
      "is_deprecated" => template.is_deprecated,
      "quality_score" => template.quality_score,
      "is_unilateral" => template.is_unilateral,
      "is_compound" => template.is_compound,
      "movement_direction" => template.movement_direction,
      "fatigue_score" => template.fatigue_score,
      "skill_requirement" => template.skill_requirement,
      "movement_pattern" => template.movement_pattern,
      "exercise_category" => template.exercise_category,
      "aliases_text" => template.aliases |> loaded_or_empty() |> Enum.map_join("\n", & &1.name),
      "muscle_names" =>
        template.template_muscles
        |> loaded_or_empty()
        |> Enum.sort_by(&{&1.position || 0, &1.id || 0})
        |> Enum.map_join("\n", & &1.exercise_muscle.name),
      "equipment_names" =>
        template.template_equipment
        |> loaded_or_empty()
        |> Enum.sort_by(&{&1.position || 0, &1.id || 0})
        |> Enum.map_join("\n", & &1.exercise_equipment.name),
      "source_name" => source && source.source,
      "source_external_id" => source && source.external_id,
      "source_url" => source && source.source_url,
      "source_payload" => payload_text(source)
    }
  end

  defp loaded_or_empty(value), do: if(Ecto.assoc_loaded?(value), do: value, else: [])

  defp payload_text(nil), do: ""
  defp payload_text(%{payload: payload}) when payload in [nil, %{}], do: ""
  defp payload_text(%{payload: payload}), do: Jason.encode!(payload, pretty: true)

  defp payload_summary(payload) when payload in [nil, %{}], do: "none"

  defp payload_summary(payload) when is_map(payload) do
    payload
    |> Map.keys()
    |> Enum.take(8)
    |> Enum.join(", ")
  end

  defp payload_summary(_payload), do: "raw"

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%b %d, %Y %H:%M")

  defp media_cache_path(media), do: media.local_path || media.storage_key || "Not cached"

  defp media_size_label(%{file_size: size}) when is_integer(size), do: "#{size} bytes"
  defp media_size_label(_media), do: "unknown size"

  defp status_label(nil), do: "unknown"

  defp status_label(status) do
    status
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp media_statuses(%ExerciseTemplate{media: media}) do
    media = loaded_or_empty(media)

    cond do
      media == [] ->
        ["missing media"]

      Enum.any?(media, &(&1.cache_status == "cached" and is_binary(&1.local_path))) ->
        ["cached media"]

      Enum.any?(media, &(&1.cache_status in ["failed", "stale"])) ->
        ["failed/broken media"]

      Enum.any?(media, &(&1.cache_status == "remote_only")) ->
        ["remote-only media"]

      true ->
        media |> Enum.map(&(&1.cache_status || "unknown")) |> Enum.uniq()
    end
  end

  defp template_back_path(%ExerciseTemplate{id: nil}), do: ~p"/admin/exercises"
  defp template_back_path(%ExerciseTemplate{id: id}), do: ~p"/admin/exercises/#{id}"

  defp errors_for(changeset) do
    if function_exported?(Ecto.Changeset, :traverse_errors, 2) do
      %{
        "_errors" =>
          inspect(Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end))
      }
    else
      %{}
    end
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp review_block(assigns) do
    ~H"""
    <section class="rounded-lg border border-base-200 p-4">
      <h3 class="text-sm font-semibold uppercase tracking-[0.14em] text-base-content/50">{@title}</h3>
      <div class="mt-4">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp review_stat(assigns) do
    ~H"""
    <div class="rounded-lg bg-base-200/60 p-3">
      <p class="text-xs font-semibold uppercase tracking-[0.12em] text-base-content/50">{@label}</p>
      <p class="mt-1 text-sm font-semibold text-base-content">{@value}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :values, :list, required: true

  defp pill_group(assigns) do
    ~H"""
    <div>
      <p class="mb-2 text-xs font-semibold uppercase tracking-[0.12em] text-base-content/50">
        {@label}
      </p>
      <div class="flex flex-wrap gap-2">
        <span
          :for={value <- @values}
          class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-semibold text-base-content/70"
        >
          {value}
        </span>
        <span :if={@values == []} class="text-sm text-base-content/50">None</span>
      </div>
    </div>
    """
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
