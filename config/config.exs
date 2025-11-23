import Config

# --- 1. 各アプリのRepo設定 ---
config :rogs_identity,
  ecto_repos: [RogsIdentity.Repo],
  generators: [context_name: :identity]

config :rogs_comm,
  ecto_repos: [RogsComm.Repo]

config :shinkanki,
  ecto_repos: [Shinkanki.Repo]

# shinkanki_web は画面だけなのでRepoは持たないが、generatorsの設定はしておく
config :shinkanki_web,
  generators: [context_name: :shinkanki]

# --- 2. 共通DB接続設定 (Project ROGs) ---
# ※ すべて "rogs_dev" という1つのDBを見に行きます

# エンドポイントの共通設定 (Banditを使用)
config :rogs_identity, RogsIdentityWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RogsIdentityWeb.ErrorHTML, json: RogsIdentityWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RogsIdentity.PubSub,
  live_view: [signing_salt: "ZBs41IVB"]

config :rogs_comm, RogsCommWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RogsCommWeb.ErrorHTML, json: RogsCommWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RogsComm.PubSub,
  live_view: [signing_salt: "ZBs41IVB"]

# shinkanki_web はまだ作成されていない可能性がありますが、設定だけ入れておきます
config :shinkanki_web, ShinkankiWebWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ShinkankiWebWeb.ErrorHTML, json: ShinkankiWebWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ShinkankiWeb.PubSub,
  live_view: [signing_salt: "ZBs41IVB"]

# 認証用
config :rogs_identity, RogsIdentity.Repo,
  username: "takashiba",
  # ⚠️ご自身の環境に合わせて変更してください
  password: "postgres",
  database: "rogs_dev",
  hostname: "localhost",
  pool_size: 10

# 通信用
config :rogs_comm, RogsComm.Repo,
  username: "takashiba",
  password: "postgres",
  database: "rogs_dev",
  hostname: "localhost",
  pool_size: 10

# ゲームロジック用
config :shinkanki, Shinkanki.Repo,
  username: "takashiba",
  password: "postgres",
  database: "rogs_dev",
  hostname: "localhost",
  pool_size: 10

# アセットツールのバージョン固定
config :esbuild, :version, "0.17.11"
config :tailwind, :version, "3.4.3"

# --- 3.1. アセット設定 (shinkanki_web) ---
config :esbuild,
  shinkanki_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/shinkanki_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  shinkanki_web: [
    args: ~w(--input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../apps/shinkanki_web/assets", __DIR__)
  ]

# --- 3. 環境設定の読み込み ---
import_config "#{config_env()}.exs"
