import Config

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Database configuration variables
db_user = System.get_env("ROGS_DB_USER", "takashiba")
db_pass = System.get_env("ROGS_DB_PASS", "postgres")
db_host = System.get_env("ROGS_DB_HOST", "localhost")
test_partition = System.get_env("MIX_TEST_PARTITION")

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :rogs_identity, RogsIdentity.Repo,
  username: db_user,
  password: db_pass,
  hostname: db_host,
  database: "rogs_identity_test#{test_partition}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "h/4sflHfmiLdRipc3zIg2n0CnufS8vnfmS/I2XmlOOUus2mbgdUq4SGQp13J/usP",
  server: false

config :rogs_comm, RogsComm.Repo,
  username: db_user,
  password: db_pass,
  hostname: db_host,
  database: "rogs_comm_test#{test_partition}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :rogs_comm, RogsCommWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "UulrLUGCQBmoqFzUQyv+i57oOdjnEjFHD0UF0X3wm4OjPGswsE57MjlUO0LSEGns",
  server: false

config :shinkanki, Shinkanki.Repo,
  username: db_user,
  password: db_pass,
  hostname: db_host,
  database: "shinkanki_test#{test_partition}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :shinkanki_web, ShinkankiWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fXs5MBA7YbZwilrl7rihhhMmEJ8GHMJ5f3uaoSMp8eVSv7LhhtAw+ykccnmnW0NG",
  server: true  # Wallaby requires server to be running

# Wallaby configuration
config :wallaby,
  driver: Wallaby.Chrome,
  otp_app: :shinkanki_web,
  base_url: "http://localhost:4002",
  screenshot_dir: "tmp/wallaby_screenshots",
  screenshot_on_failure: true,
  chromedriver: [
    headless: true
  ]

# Note: For feature tests, repos must be started
# These settings are enabled for Wallaby E2E tests
config :shinkanki, start_repo: true
config :shinkanki, start_game_session_cache: true

# In test we don't send emails
config :rogs_identity, RogsIdentity.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
