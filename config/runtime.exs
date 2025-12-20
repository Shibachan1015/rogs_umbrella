import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# --- Debug Logging Configuration ---
# Set DEBUG_LOGGING=true to enable verbose debug logs
debug_logging = System.get_env("DEBUG_LOGGING") in ~w(true 1)
config :shinkanki_web, :debug_logging, debug_logging

# --- OAuth and API Key Configuration (loaded from environment) ---

if claude_api_key = System.get_env("ANTHROPIC_API_KEY") do
  config :shinkanki, :ai_provider, :claude
  config :shinkanki, :claude_api_key, claude_api_key
else
  # Fallback to local AI if Claude API key is not present
  config :shinkanki, :ai_provider, :local
end

if google_client_id = System.get_env("GOOGLE_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: google_client_id,
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
end

if github_client_id = System.get_env("GITHUB_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: github_client_id,
    client_secret: System.get_env("GITHUB_CLIENT_SECRET")
end

# --- Production-Specific Configuration ---
# Note: PHX_SERVER is set by Fly.io for releases, more reliable than MIX_ENV
# which is not available as an environment variable in releases.

if System.get_env("PHX_SERVER") == "true" || System.get_env("RELEASE_NAME") do
  # Main Endpoint Configuration
  # This section configures the main web endpoint for the application.
  host = System.get_env("PHX_HOST") || "rogs-umbrella.fly.dev"
  port = String.to_integer(System.get_env("PORT") || "8080")
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing"

  config :shinkanki_web, ShinkankiWebWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    check_origin: [
      "//rogs.live",
      "//*.rogs.live",
      "//rogs-umbrella.fly.dev"
    ]

  # Database Configuration
  # This single DATABASE_URL is used for all Ecto repos in the umbrella app.
  # Ensure the database user has permissions for all required tables.
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing"

  ecto_pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # Fly.io internal network uses encrypted 6PN, but SSL can be enabled if needed
  # Set DATABASE_SSL=true to enable SSL for database connections
  database_ssl = System.get_env("DATABASE_SSL") in ~w(true 1)

  repo_opts = [
    url: database_url,
    pool_size: ecto_pool_size,
    socket_options: maybe_ipv6,
    ssl: database_ssl,
    ssl_opts: if(database_ssl, do: [verify: :verify_none], else: [])
  ]

  config :shinkanki, Shinkanki.Repo, repo_opts
  config :rogs_comm, RogsComm.Repo, repo_opts
  config :rogs_identity, RogsIdentity.Repo, repo_opts

  # Mailer (Swoosh) Configuration
  # Disabling the API client by default to prevent crashes if no email service is configured.
  # To enable email sending, configure a real adapter (e.g., Mailgun)
  # and the appropriate API client (e.g., Req or Finch) here.
  config :swoosh, :api_client, false
end