defmodule FittrackWeb.Router do
  use FittrackWeb, :router

  import FittrackWeb.UserAuth

  # Simple plug to set default locale to English
  defmodule SetLocale do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      Gettext.put_locale(FittrackWeb.Gettext, "en")
      conn
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FittrackWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug SetLocale
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
      live "/dashboard", DashboardLive.Index, :index

      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      # Exercises (protected)
      live "/exercises", ExerciseLive.Index, :index
      live "/exercises/new", ExerciseLive.Form, :new
      live "/exercises/:id/edit", ExerciseLive.Form, :edit
      live "/exercises/:id", ExerciseLive.Show, :show

      # Exercise Library
      live "/library", LibraryLive.Index, :index
      live "/library/:id", LibraryLive.Show, :show

      # Workout Plans
      live "/workout-plans", WorkoutPlanLive.Index, :index
      live "/workout-plans/new", WorkoutPlanLive.Form, :new
      live "/workout-plans/:id/edit", WorkoutPlanLive.Form, :edit
      live "/workout-plans/:id", WorkoutPlanLive.Show, :show

      live "/workouts", WorkoutLive.Index, :index
      live "/workouts/new", WorkoutLive.New, :new
      live "/workouts/:id", WorkoutLive.Show, :show

      # Backwards compatible redirects (old session URLs)
      get "/sessions", RedirectController, :workouts_redirect
      get "/sessions/new", RedirectController, :new_workout_redirect
      get "/sessions/:id", RedirectController, :workout_redirect
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
