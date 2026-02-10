# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fittrack, :scopes,
  user: [
    default: true,
    module: Fittrack.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Fittrack.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :fittrack,
  ecto_repos: [Fittrack.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :fittrack, FittrackWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FittrackWeb.ErrorHTML, json: FittrackWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fittrack.PubSub,
  live_view: [signing_salt: "rKUVnN+m"]

# Configure the mailer
#
# In dev, use the "Local" adapter which stores emails locally
# (viewable at "/dev/mailbox" when dev routes are enabled).
#
# In production, configure a real adapter (Mailgun/SMTP/etc.)
# in `config/runtime.exs`.
if config_env() == :dev do
  config :fittrack, Fittrack.Mailer, adapter: Swoosh.Adapters.Local
end

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  fittrack: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  fittrack: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
