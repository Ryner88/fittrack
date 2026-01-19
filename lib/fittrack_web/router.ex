defmodule FittrackWeb.Router do
  use FittrackWeb, :router

  import FittrackWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FittrackWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FittrackWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  if Application.compile_env(:fittrack, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FittrackWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FittrackWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{FittrackWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      # Exercises (protected)
      live "/exercises", ExerciseLive.Index, :index
      live "/exercises/new", ExerciseLive.Index, :new
      live "/exercises/:id/edit", ExerciseLive.Index, :edit
      live "/exercises/:id", ExerciseLive.Show, :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", FittrackWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{FittrackWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
