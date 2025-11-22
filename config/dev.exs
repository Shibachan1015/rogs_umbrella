import Config

# --- 開発環境の共通設定 ---
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# --- Webサーバーの設定 (ポート番号を動的にする) ---

# 1. 認証アプリ (RogsIdentity)
config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  # アセットビルドは一旦なし
  watchers: []

# 2. 通信アプリ (RogsComm)
config :rogs_comm, RogsCommWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT_COMM") || "4001")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# 3. ゲームUIアプリ (ShinkankiWeb)
config :shinkanki_web, ShinkankiWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT_UI") || "4002")],
  secret_key_base: "Hu4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4qKBq+x1jC8q4q",
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/shinkanki_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]
