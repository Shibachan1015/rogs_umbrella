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
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "shinkanki_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

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
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :rogs_comm, RogsComm.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rogs_comm_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rogs_comm, RogsCommWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "UulrLUGCQBmoqFzUQyv+i57oOdjnEjFHD0UF0X3wm4OjPGswsE57MjlUO0LSEGns",
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
config :rogs_identity, RogsIdentity.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rogs_identity_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "h/4sflHfmiLdRipc3zIg2n0CnufS8vnfmS/I2XmlOOUus2mbgdUq4SGQp13J/usP",
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
config :rogs, Rogs.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rogs_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rogs_web, RogsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "csnjiTZtZULDNlS6nqQShgZbtEDap3+CtQPkk5gpMJBZIuPTtc7dNcCFAjbZ/D9+",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails
config :rogs, Rogs.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
