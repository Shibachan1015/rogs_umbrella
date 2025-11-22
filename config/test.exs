import Config

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
  server: false
