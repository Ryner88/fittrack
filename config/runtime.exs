import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts.

# If you use `mix release`, enable the server by setting:
#   PHX_SERVER=true
if System.get_env("PHX_SERVER") do
  config :fittrack, FittrackWeb.Endpoint, server: true
end

# Non-SMTP Swoosh adapters (like Mailgun) need an API client.
# You already have :req in deps, so use Req.
config :swoosh, :api_client, Swoosh.ApiClient.Req

# Default HTTP port for all envs (can be overridden/expanded in :prod below)
config :fittrack, FittrackWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if openai_api_key = System.get_env("OPENAI_API_KEY") do
  config :fittrack, :openai_api_key, openai_api_key
end

if screenshot_import_model = System.get_env("SCREENSHOT_IMPORT_MODEL") do
  config :fittrack, :screenshot_import_model, screenshot_import_model
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :fittrack, Fittrack.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "fitness.nextgenbytes.me"

  config :fittrack, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :fittrack, FittrackWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT", "4000"))
    ],
    secret_key_base: secret_key_base

  # ---- Mailer (Mailgun) ----
  config :fittrack, Fittrack.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.fetch_env!("MAILGUN_API_KEY"),
    domain: System.fetch_env!("MAILGUN_DOMAIN")

  # If you use Mailgun EU region, uncomment:
  # config :fittrack, Fittrack.Mailer, base_url: "https://api.eu.mailgun.net/v3"
end
