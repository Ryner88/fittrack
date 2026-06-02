defmodule FittrackWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FittrackWeb, :html

  alias Fittrack.Training

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assign(assigns, :active_workout, active_workout(assigns[:current_scope]))

    ~H"""
    <div class="min-h-screen relative bg-gradient-to-b from-base-200 via-base-200 to-base-100">
      <div class="pointer-events-none fixed inset-0 opacity-[0.04]
               bg-[radial-gradient(circle_at_1px_1px,rgba(255,255,255,0.35)_1px,transparent_0)]
               [background-size:24px_24px]">
      </div>

      <div class="relative">
        <header class="border-b border-base-200 bg-base-100/80 backdrop-blur">
          <div class="mx-auto flex w-full max-w-6xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
            <div class="flex items-center gap-3">
              <.link navigate={~p"/"} class="flex items-center gap-3 text-base-content">
                <img src="/images/logo.svg" width="36" alt="Fittrack logo" />
                <div>
                  <p class="text-sm font-semibold">Fittrack</p>
                  <p class="text-xs text-base-content/60">Training tracker</p>
                </div>
              </.link>
            </div>

            <nav class="hidden items-center gap-2 text-sm font-semibold text-base-content md:flex">
              <%= if @current_scope && @current_scope.user do %>
                <.link
                  navigate={~p"/dashboard"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  Dashboard
                </.link>
                <.link
                  navigate={~p"/nutrition"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  Nutrition
                </.link>
                <.link
                  navigate={~p"/exercises"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  Library
                </.link>
                <.link
                  navigate={~p"/my-exercises"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  My Exercises
                </.link>
                <.link
                  navigate={~p"/workout-plans"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  Plans
                </.link>
                <.link
                  navigate={~p"/workout-history"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  History
                </.link>
                <.link
                  navigate={~p"/one-rep-max"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  1RM
                </.link>
              <% else %>
                <.link
                  navigate={~p"/"}
                  class="rounded-full px-3 py-2 transition hover:bg-base-200"
                >
                  Home
                </.link>
              <% end %>
            </nav>

            <div class="flex items-center gap-3">
              <%= if @current_scope && @current_scope.user do %>
                <button
                  id="command-bar-open"
                  type="button"
                  data-command-open
                  class="hidden items-center gap-2 rounded-full border border-base-300 px-3 py-2 text-xs font-semibold text-base-content transition hover:border-primary hover:text-primary lg:inline-flex"
                >
                  <.icon name="hero-magnifying-glass" class="h-4 w-4" />
                  <span>Search</span>
                  <kbd class="rounded bg-base-200 px-1.5 py-0.5 text-[0.65rem] font-semibold text-base-content/60">
                    Ctrl K
                  </kbd>
                </button>
                <.workout_cta active_workout={@active_workout} id_prefix="header" />
                <details class="group relative">
                  <summary
                    id="profile-menu-button"
                    class="flex cursor-pointer list-none items-center gap-2 rounded-full border border-base-300 px-3 py-2 text-xs font-semibold text-base-content transition hover:border-primary hover:text-primary"
                  >
                    <.icon name="hero-user-circle" class="h-4 w-4" />
                    <span class="hidden sm:inline">Profile</span>
                    <.icon name="hero-chevron-down" class="h-3 w-3 transition group-open:rotate-180" />
                  </summary>
                  <div class="absolute right-0 z-20 mt-3 w-64 rounded-xl border border-base-200 bg-base-100 p-2 shadow-xl">
                    <div class="border-b border-base-200 px-3 py-2">
                      <p class="truncate text-sm font-semibold text-base-content">
                        {@current_scope.user.email}
                      </p>
                    </div>
                    <.link
                      id="profile-settings-link"
                      navigate={~p"/users/settings"}
                      class="mt-2 flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200"
                    >
                      <.icon name="hero-cog-6-tooth" class="h-4 w-4" /> Settings
                    </.link>
                    <div class="mt-2 px-3 py-2">
                      <p class="mb-2 text-xs font-semibold uppercase tracking-[0.16em] text-base-content/50">
                        Theme
                      </p>
                      <.theme_toggle />
                    </div>
                    <.link
                      id="profile-log-out-link"
                      href={~p"/users/log-out"}
                      method="delete"
                      class="mt-2 flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200 hover:text-primary"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" /> Log out
                    </.link>
                  </div>
                </details>
              <% else %>
                <.link
                  navigate={~p"/users/log-in"}
                  class="inline-flex items-center justify-center rounded-full border border-base-300 px-3 py-2 text-xs font-semibold text-base-content transition hover:border-primary hover:text-primary"
                >
                  Log in
                </.link>
                <.link
                  navigate={~p"/users/register"}
                  class="inline-flex items-center justify-center rounded-full bg-primary px-3 py-2 text-xs font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                >
                  Register
                </.link>
                <.theme_toggle />
              <% end %>
            </div>
          </div>
        </header>

        <main class="px-4 py-10 sm:px-6 lg:px-8">
          <div class="mx-auto w-full max-w-6xl">
            {render_slot(@inner_block)}
          </div>
        </main>

        <%= if @current_scope && @current_scope.user do %>
          <.command_bar active_workout={@active_workout} />
        <% end %>

        <.flash_group flash={@flash} />
      </div>
    </div>
    """
  end

  attr :active_workout, :map, default: nil
  attr :id_prefix, :string, required: true

  defp workout_cta(assigns) do
    ~H"""
    <%= if @active_workout do %>
      <.link
        id={"#{@id_prefix}-resume-workout-link"}
        navigate={~p"/workouts/#{@active_workout}"}
        class="hidden items-center justify-center rounded-full bg-primary px-4 py-2 text-xs font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90 sm:inline-flex"
      >
        <.icon name="hero-play" class="mr-2 h-4 w-4" /> Resume workout
      </.link>
    <% else %>
      <.link
        id={"#{@id_prefix}-start-workout-link"}
        navigate={~p"/workouts/new"}
        class="hidden items-center justify-center rounded-full bg-primary px-4 py-2 text-xs font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90 sm:inline-flex"
      >
        <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Start workout
      </.link>
    <% end %>
    """
  end

  defp active_workout(%{user: %{}} = current_scope),
    do: Training.get_active_workout(current_scope)

  defp active_workout(_current_scope), do: nil

  attr :active_workout, :map, default: nil

  defp command_bar(assigns) do
    ~H"""
    <div
      id="command-bar"
      phx-hook="CommandBar"
      phx-update="ignore"
      class="fixed inset-0 z-40 hidden"
      role="dialog"
      aria-modal="true"
      aria-labelledby="command-bar-title"
    >
      <button
        type="button"
        data-command-close
        class="absolute inset-0 h-full w-full cursor-default bg-base-content/30 backdrop-blur-sm"
        aria-label="Close command bar"
      >
      </button>
      <div class="relative mx-auto mt-20 w-[min(42rem,calc(100vw-2rem))] overflow-hidden rounded-2xl border border-base-200 bg-base-100 shadow-2xl">
        <div class="border-b border-base-200 p-4">
          <div class="flex items-center gap-3">
            <.icon name="hero-magnifying-glass" class="h-5 w-5 text-base-content/45" />
            <div class="min-w-0 flex-1">
              <h2 id="command-bar-title" class="sr-only">Command bar</h2>
              <input
                id="command-bar-input"
                data-command-input
                type="search"
                autocomplete="off"
                placeholder="Search actions, pages, and tools"
                class="w-full border-0 bg-transparent text-base font-semibold text-base-content outline-none placeholder:text-base-content/40"
              />
            </div>
            <kbd class="rounded-md border border-base-200 bg-base-50 px-2 py-1 text-xs font-semibold text-base-content/50">
              Esc
            </kbd>
          </div>
        </div>

        <div class="max-h-[70vh] overflow-y-auto p-3">
          <.command_group title="Workout">
            <%= if @active_workout do %>
              <.command_item
                href={~p"/workouts/#{@active_workout}"}
                icon="hero-play"
                title="Resume workout"
                description="Continue the active workout in progress"
                keywords="active continue workout log set"
              />
              <.command_item
                href={~p"/workouts/#{@active_workout}"}
                icon="hero-plus-circle"
                title="Log set"
                description="Jump to the active workout set form"
                keywords="performed reps weight set"
              />
            <% else %>
              <.command_item
                href={~p"/workouts/new"}
                icon="hero-plus"
                title="Start empty workout"
                description="Begin a blank workout session"
                keywords="start workout empty session"
              />
              <.command_item
                href={~p"/workout-plans"}
                icon="hero-clipboard-document-list"
                title="Start from plan"
                description="Choose a reusable workout template"
                keywords="plans templates routine"
              />
            <% end %>
          </.command_group>

          <.command_group title="Navigate">
            <.command_item
              href={~p"/dashboard"}
              icon="hero-chart-bar"
              title="Dashboard"
              description="Progress, summaries, and charts"
              keywords="home stats progress"
            />
            <.command_item
              href={~p"/nutrition"}
              icon="hero-fire"
              title="Nutrition"
              description="Meals, weekly planner, and intake dashboard"
              keywords="meals food calories macros"
            />
            <.command_item
              href={~p"/exercises"}
              icon="hero-bolt"
              title="Exercise Library"
              description="Browse public exercises and movement details"
              keywords="movements lifts library"
            />
            <.command_item
              href={~p"/my-exercises"}
              icon="hero-user-circle"
              title="My Exercises"
              description="Manage personal exercise library"
              keywords="custom exercises personal movements"
            />
            <.command_item
              href={~p"/workout-plans"}
              icon="hero-clipboard-document-list"
              title="Plans"
              description="Reusable workout templates"
              keywords="templates routines plans"
            />
            <.command_item
              href={~p"/workout-history"}
              icon="hero-calendar-days"
              title="History"
              description="Completed workouts and calendar"
              keywords="completed calendar records"
            />
            <.command_item
              href={~p"/one-rep-max"}
              icon="hero-calculator"
              title="1RM Calculator"
              description="Estimate max strength and training percentages"
              keywords="one rep max strength percentage calculator"
            />
          </.command_group>

          <.command_group title="Create">
            <.command_item
              href={~p"/meals/new"}
              icon="hero-plus"
              title="Log meal"
              description="Create a meal and import nutrition"
              keywords="nutrition food barcode screenshot"
            />
            <.command_item
              href={~p"/meal-plans/new"}
              icon="hero-calendar"
              title="Build weekly meal plan"
              description="Create a reusable nutrition plan"
              keywords="weekly nutrition planner"
            />
            <.command_item
              href={~p"/workout-plans/generator"}
              icon="hero-sparkles"
              title="AI workout generator"
              description="Generate a workout plan from goals and equipment"
              keywords="ai generate plan"
            />
          </.command_group>

          <div
            data-command-empty
            class="hidden rounded-xl border border-dashed border-base-300 p-6 text-center text-sm text-base-content/65"
          >
            No commands match that search.
          </div>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :title, :string, required: true

  defp command_group(assigns) do
    ~H"""
    <section data-command-group class="mb-3">
      <h3 class="px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-base-content/45">
        {@title}
      </h3>
      <div class="space-y-1">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :keywords, :string, default: ""

  defp command_item(assigns) do
    ~H"""
    <.link
      navigate={@href}
      data-command-item
      data-command-keywords={"#{@title} #{@description} #{@keywords}"}
      class="group flex items-center gap-3 rounded-xl px-3 py-3 text-left transition hover:bg-base-200 focus:bg-base-200 focus:outline-none"
    >
      <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border border-base-200 bg-base-50 text-base-content/70 group-hover:border-primary/30 group-hover:text-primary">
        <.icon name={@icon} class="h-4 w-4" />
      </span>
      <span class="min-w-0">
        <span class="block text-sm font-semibold text-base-content">{@title}</span>
        <span class="mt-0.5 block truncate text-xs text-base-content/60">{@description}</span>
      </span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
