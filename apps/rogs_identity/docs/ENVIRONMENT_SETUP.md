# 環境設定ガイド

このドキュメントは、`rogs_identity`の環境設定方法を説明します。

## 目次

1. [データベース環境変数](#データベース環境変数)
2. [開発環境の設定](#開発環境の設定)
3. [テスト環境の設定](#テスト環境の設定)
4. [本番環境の設定](#本番環境の設定)
5. [環境変数の一覧](#環境変数の一覧)

## データベース環境変数

### 必須環境変数

以下の環境変数は、データベース接続に使用されます：

- `ROGS_DB_USER`: データベースユーザー名（デフォルト: `takashiba`）
- `ROGS_DB_PASS`: データベースパスワード（デフォルト: `postgres`）
- `ROGS_DB_HOST`: データベースホスト（デフォルト: `localhost`）

### 設定方法

#### macOS/Linux

```bash
# .env ファイルを作成（推奨）
export ROGS_DB_USER=your_username
export ROGS_DB_PASS=your_password
export ROGS_DB_HOST=localhost

# または、シェル設定ファイルに追加
echo 'export ROGS_DB_USER=your_username' >> ~/.zshrc
echo 'export ROGS_DB_PASS=your_password' >> ~/.zshrc
echo 'export ROGS_DB_HOST=localhost' >> ~/.zshrc
source ~/.zshrc
```

#### Windows

```cmd
# コマンドプロンプト
set ROGS_DB_USER=your_username
set ROGS_DB_PASS=your_password
set ROGS_DB_HOST=localhost

# PowerShell
$env:ROGS_DB_USER="your_username"
$env:ROGS_DB_PASS="your_password"
$env:ROGS_DB_HOST="localhost"
```

### データベースの作成

環境変数を設定した後、データベースを作成します：

```bash
# 開発環境
mix ecto.create

# テスト環境
MIX_ENV=test mix ecto.create
```

## 開発環境の設定

### ポート設定

開発環境では、以下のポートが使用されます：

- `rogs_identity`: 4000（`PORT`環境変数で変更可能）
- `rogs_comm`: 4001（`PORT_COMM`環境変数で変更可能）
- `shinkanki_web`: 4002（`PORT_UI`環境変数で変更可能）

### 設定ファイル

開発環境の設定は`config/dev.exs`にあります：

```elixir
config :rogs_identity, RogsIdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  secret_key_base: "...",
  debug_errors: true,
  code_reloader: true,
  check_origin: false
```

### 起動方法

```bash
# データベースのセットアップ
mix ecto.create
mix ecto.migrate

# サーバーの起動
mix phx.server

# または、特定のポートで起動
PORT=4000 mix phx.server
```

### 開発環境の特徴

- **コードリロード**: ファイル変更時に自動リロード
- **デバッグエラー**: 詳細なエラーメッセージを表示
- **LiveDashboard**: `/dev/dashboard`でアクセス可能（開発時のみ）

## テスト環境の設定

### データベース設定

テスト環境では、パーティション付きデータベースが使用されます：

```elixir
config :rogs_identity, RogsIdentity.Repo,
  username: System.get_env("ROGS_DB_USER", "takashiba"),
  password: System.get_env("ROGS_DB_PASS", "postgres"),
  hostname: System.get_env("ROGS_DB_HOST", "localhost"),
  database: "rogs_identity_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

### テストの実行

```bash
# すべてのテストを実行
mix test

# 特定のテストファイルを実行
mix test apps/rogs_identity/test/rogs_identity_web/integration_test.exs

# 特定のテストを実行
mix test apps/rogs_identity/test/rogs_identity_web/integration_test.exs:50
```

### テスト環境の特徴

- **SQL Sandbox**: 各テストが独立したトランザクションで実行
- **並列実行**: 複数のテストを並列で実行可能
- **パーティション**: `MIX_TEST_PARTITION`でテストを分離

## 本番環境の設定

### 必須環境変数

本番環境では、以下の環境変数が必須です：

- `SECRET_KEY_BASE`: Cookie署名用の秘密鍵
- `ROGS_DB_USER`: データベースユーザー名
- `ROGS_DB_PASS`: データベースパスワード
- `ROGS_DB_HOST`: データベースホスト
- `PHX_HOST`: アプリケーションのホスト名
- `PORT`: サーバーのポート番号（オプション、デフォルト: 4000）

### SECRET_KEY_BASEの生成

```bash
mix phx.gen.secret
```

生成された値を環境変数に設定します。

### 設定ファイル

本番環境の設定は`config/runtime.exs`にあります：

```elixir
if config_env() == :prod do
  secret_key_base = System.get_env("SECRET_KEY_BASE") ||
    raise "environment variable SECRET_KEY_BASE is missing."

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :rogs_identity, RogsIdentityWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end
```

### データベース設定

本番環境のデータベース設定は`config/runtime.exs`で行います：

```elixir
config :rogs_identity, RogsIdentity.Repo,
  username: System.get_env("ROGS_DB_USER"),
  password: System.get_env("ROGS_DB_PASS"),
  hostname: System.get_env("ROGS_DB_HOST"),
  database: System.get_env("ROGS_DB_NAME") || "rogs_identity_prod",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

### SSL/TLS設定

本番環境では、HTTPSを使用することを強く推奨します：

```elixir
config :rogs_identity, RogsIdentityWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
    certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  ],
  force_ssl: [hsts: true]
```

## 環境変数の一覧

### データベース関連

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `ROGS_DB_USER` | データベースユーザー名 | `takashiba` | 開発/テスト: いいえ、本番: はい |
| `ROGS_DB_PASS` | データベースパスワード | `postgres` | 開発/テスト: いいえ、本番: はい |
| `ROGS_DB_HOST` | データベースホスト | `localhost` | 開発/テスト: いいえ、本番: はい |
| `ROGS_DB_NAME` | データベース名 | 環境に応じて自動設定 | いいえ |

### アプリケーション関連

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `PORT` | サーバーのポート番号 | `4000` | いいえ |
| `PHX_HOST` | アプリケーションのホスト名 | `example.com` | 本番: はい |
| `SECRET_KEY_BASE` | Cookie署名用の秘密鍵 | - | 本番: はい |

### テスト関連

| 変数名 | 説明 | デフォルト | 必須 |
|--------|------|-----------|------|
| `MIX_TEST_PARTITION` | テストパーティション | - | いいえ |

## 環境ごとの設定の違い

### 開発環境

- **データベース**: `rogs_identity_dev`
- **デバッグ**: 有効
- **コードリロード**: 有効
- **エラーページ**: 詳細なスタックトレース

### テスト環境

- **データベース**: `rogs_identity_test`（パーティション付き）
- **デバッグ**: 無効
- **コードリロード**: 無効
- **SQL Sandbox**: 有効

### 本番環境

- **データベース**: 環境変数で指定
- **デバッグ**: 無効
- **コードリロード**: 無効
- **HTTPS**: 推奨
- **エラーページ**: 簡潔なエラーメッセージ

## トラブルシューティング

### データベース接続エラー

**エラー**: `(Postgrex.Error) FATAL: password authentication failed`

**解決方法**:
1. `ROGS_DB_USER`と`ROGS_DB_PASS`が正しいか確認
2. PostgreSQLが起動しているか確認
3. データベースユーザーが存在するか確認

### ポートが既に使用されている

**エラー**: `(PortAlreadyInUse) port 4000 is already in use`

**解決方法**:
```bash
# 別のポートを使用
PORT=4001 mix phx.server

# または、使用中のプロセスを終了
lsof -ti:4000 | xargs kill
```

### 環境変数が読み込まれない

**解決方法**:
1. 環境変数が正しく設定されているか確認
2. シェルを再起動
3. `.env`ファイルを使用している場合、読み込みを確認

## 参考資料

- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Ecto Configuration](https://hexdocs.pm/ecto/Ecto.Repo.html#module-connection-options)

