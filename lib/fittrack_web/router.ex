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
    get "/exercise-media/:id", ExerciseTemplateImageController, :media
    get "/exercise-template-images/:id", ExerciseTemplateImageController, :show
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

      # My Exercises (protected personal exercise CRUD)
      live "/my-exercises", ExerciseLive.Index, :index
      live "/my-exercises/new", ExerciseLive.Form, :new
      live "/my-exercises/:id/edit", ExerciseLive.Form, :edit
      live "/my-exercises/:id", ExerciseLive.Show, :show

      # Workout Plans
      live "/workout-plans", WorkoutPlanLive.Index, :index
      live "/workout-plans/generator", WorkoutPlanLive.Generator, :new
      live "/workout-plans/new", WorkoutPlanLive.Form, :new
      live "/workout-plans/:id/edit", WorkoutPlanLive.Form, :edit
      live "/workout-plans/:id", WorkoutPlanLive.Show, :show

      live "/workouts", WorkoutLive.Index, :index
      live "/workouts/new", WorkoutLive.New, :new
      live "/workouts/:id", WorkoutLive.Show, :show

      live "/workout-history", WorkoutHistoryLive.Index, :index
      live "/one-rep-max", OneRepMaxLive.Index, :index
      live "/nutrition", NutritionLive.Index, :index

      # Meals
      live "/meals", MealLive.Index, :index
      live "/meals/new", MealLive.Form, :new
      live "/meals/:id/edit", MealLive.Form, :edit
      live "/meals/:id", MealLive.Show, :show

      # Meal Plans
      live "/meal-plans", MealPlanLive.Index, :index
      live "/meal-plans/new", MealPlanLive.Form, :new
      live "/meal-plans/:id/edit", MealPlanLive.Form, :edit
      live "/meal-plans/:id", MealPlanLive.Show, :show

      # Food Library
      live "/foods", FoodLive.Index, :index
      live "/foods/new", FoodLive.Form, :new
      live "/foods/:id/edit", FoodLive.Form, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", FittrackWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :require_admin_user,
      on_mount: [{FittrackWeb.UserAuth, :require_admin}] do
      # Exercise Admin: authenticated admin-only CRUD for shared exercise templates.
      live "/admin/exercises", Admin.ExerciseLibraryLive, :index
      live "/admin/exercises/media", Admin.ExerciseLibraryLive, :media
      live "/admin/exercises/new", Admin.ExerciseLibraryLive, :new
      live "/admin/exercises/:id", Admin.ExerciseLibraryLive, :show
      live "/admin/exercises/:id/edit", Admin.ExerciseLibraryLive, :edit
    end
  end

  scope "/", FittrackWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{FittrackWeb.UserAuth, :mount_current_scope}] do
      # Public exercise library; this live_session mounts current_scope for both guests and signed-in users.
      live "/exercises", LibraryLive.Index, :index
      live "/exercises/category/:slug", LibraryLive.Index, :category
      live "/exercises/muscle/:slug", LibraryLive.Index, :muscle
      live "/exercises/:slug", LibraryLive.Show, :show

      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
