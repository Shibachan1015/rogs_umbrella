import Config

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# --- 開発環境の共通設定 ---
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# --- Webサーバーの設定 (ポート番号を動的にする) ---

# 1. ゲームUIアプリ (ShinkankiWeb) - Main Port
config :shinkanki_web, ShinkankiWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:shinkanki_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:shinkanki_web, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/shinkanki_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# 2. 認証アプリ (RogsIdentity)
config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT_ID") || "4001")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# 3. 通信アプリ (RogsComm)
config :rogs_comm, RogsCommWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT_COMM") || "4002")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Swoosh設定（開発環境ではAPIクライアントを無効化）
config :swoosh, :api_client, false
