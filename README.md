# ROGs Identity

ROGs Umbrellaプロジェクトの認証システムです。

## 概要

`rogs_identity`は、ROGs Umbrellaプロジェクト全体で使用される認証システムです。以下の機能を提供します：

- ユーザー登録・ログイン
- パスワードリセット
- メール確認
- セッション管理
- API認証
- 他のアプリケーションとの認証連携

## クイックスタート

### 前提条件

- Elixir 1.19以上
- PostgreSQL
- 環境変数の設定（オプション）

### セットアップ

1. **依存関係のインストール**

```bash
mix deps.get
```

2. **データベースのセットアップ**

```bash
# 環境変数の設定（オプション）
export ROGS_DB_USER=your_username
export ROGS_DB_PASS=your_password
export ROGS_DB_HOST=localhost

# データベースの作成とマイグレーション
mix ecto.create
mix ecto.migrate
```

3. **サーバーの起動**

```bash
mix phx.server
```

サーバーは `http://localhost:4000` で起動します。

## ドキュメント

詳細なドキュメントは `apps/rogs_identity/docs/` ディレクトリにあります：

- [統合ガイド](apps/rogs_identity/docs/INTEGRATION_GUIDE.md) - 他のアプリからの利用方法
- [アーキテクチャドキュメント](apps/rogs_identity/docs/ARCHITECTURE.md) - システムの内部構造
- [API仕様書](apps/rogs_identity/docs/API_SPEC.md) - RESTful APIの仕様
- [環境設定ガイド](apps/rogs_identity/docs/ENVIRONMENT_SETUP.md) - 環境変数の設定方法

## 環境変数

### データベース設定

- `ROGS_DB_USER`: データベースユーザー名（デフォルト: `takashiba`）
- `ROGS_DB_PASS`: データベースパスワード（デフォルト: `postgres`）
- `ROGS_DB_HOST`: データベースホスト（デフォルト: `localhost`）

詳細は [環境設定ガイド](apps/rogs_identity/docs/ENVIRONMENT_SETUP.md) を参照してください。

## テスト

```bash
# すべてのテストを実行
mix test

# 特定のアプリのテストを実行
mix test apps/rogs_identity

# 特定のテストファイルを実行
mix test apps/rogs_identity/test/rogs_identity_web/integration_test.exs
```

## プロジェクト構造

```
apps/rogs_identity/
├── lib/
│   ├── rogs_identity/          # コアコンテキスト
│   │   ├── accounts.ex         # ユーザー管理
│   │   └── plug.ex             # 他のアプリ向けPlug
│   └── rogs_identity_web/      # Webレイヤー
│       ├── controllers/        # コントローラー
│       ├── live/               # LiveView
│       └── router.ex           # ルーティング
├── test/                       # テスト
└── docs/                       # ドキュメント
```

## ライセンス

このプロジェクトはROGs Umbrellaプロジェクトの一部です。
