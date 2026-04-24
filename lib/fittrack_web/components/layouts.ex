defmodule FittrackWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FittrackWeb, :html

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
                  Exercises
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
                <span class="hidden text-xs text-base-content/60 sm:inline">
                  {@current_scope.user.email}
                </span>
                <.link
                  href={~p"/users/log-out"}
                  method="delete"
                  class="inline-flex items-center justify-center rounded-full border border-base-300 px-3 py-2 text-xs font-semibold text-base-content transition hover:border-primary hover:text-primary"
                >
                  Log out
                </.link>
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
                  Create account
                </.link>
              <% end %>
              <.theme_toggle />
            </div>
          </div>
        </header>

        <main class="px-4 py-10 sm:px-6 lg:px-8">
          <div class="mx-auto w-full max-w-6xl">
            {render_slot(@inner_block)}
          </div>
        </main>

        <.flash_group flash={@flash} />
      </div>
    </div>
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
