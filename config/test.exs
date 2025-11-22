import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shinkanki_web, ShinkankiWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fXs5MBA7YbZwilrl7rihhhMmEJ8GHMJ5f3uaoSMp8eVSv7LhhtAw+ykccnmnW0NG",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :shinkanki, Shinkanki.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# Disable Repo start in test
config :shinkanki, :start_repo, false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shinkanki, ShinkankiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "hH3wMmyVk/jIkQrq2ZSOyJjbN+lNYvgAHZ+2+lKR0koxskyw+JzoDSdv3X3P57qw",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :rogs_comm, RogsComm.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
config :rogs_comm, :start_repo, false

config :rogs_comm, RogsCommWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "UulrLUGCQBmoqFzUQyv+i57oOdjnEjFHD0UF0X3wm4OjPGswsE57MjlUO0LSEGns",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :rogs_identity, RogsIdentity.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
config :rogs_identity, :start_repo, false

config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "h/4sflHfmiLdRipc3zIg2n0CnufS8vnfmS/I2XmlOOUus2mbgdUq4SGQp13J/usP",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :rogs, Rogs.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
config :rogs, :start_repo, false

config :rogs_web, RogsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "csnjiTZtZULDNlS6nqQShgZbtEDap3+CtQPkk5gpMJBZIuPTtc7dNcCFAjbZ/D9+",
  server: false

config :logger, level: :warning
config :rogs, Rogs.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
