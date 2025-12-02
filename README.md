# 神環記 (Shinkanki)

**空環 Akasha 年代記** - 森・文化・社会・通貨の4つのパラメータを操り、文明の循環を司るカードゲーム

## デザインシステム

このリポジトリのUI実装は **Torii Resonance Design System (TRDS)** を基準にしています。色やタイポグラフィ、コンポーネント規約については [`docs/torii_resonance_design_system.md`](docs/torii_resonance_design_system.md) を参照してください。

## 概要

神環記は、Phoenix LiveViewで構築されたリアルタイムマルチプレイヤーカードゲームです。

### ゲームの特徴

- **4つのパラメータ**: 森（自然）、文化、社会、通貨のバランスを管理
- **3つのフェーズ**: 季節フェーズ → 行動フェーズ → 精算フェーズ
- **邪気システム**: パラメータの極端な偏りが邪気を生み、文明崩壊へ導く
- **リアルタイム対戦**: WebSocketによるリアルタイムな状態同期

## プロジェクト構造

Umbrellaプロジェクトとして構成されています：

```
apps/
├── shinkanki/          # ゲームロジック（コアドメイン）
├── shinkanki_web/      # Phoenix LiveView（WebUI）
├── rogs_comm/          # 共通ユーティリティ（ルーム管理等）
└── rogs_identity/      # 認証システム
```

## クイックスタート

### 前提条件

- Elixir 1.17以上
- Erlang/OTP 27以上
- PostgreSQL
- Node.js 20以上（アセットビルド用）

### セットアップ

```bash
# 依存関係のインストール
mix deps.get

# アセットのセットアップ
cd apps/shinkanki_web/assets && npm install && cd ../../..

# データベースのセットアップ
mix ecto.create
mix ecto.migrate

# サーバーの起動
mix phx.server
```

サーバーは `http://localhost:4000` で起動します。

## 開発

### テスト

```bash
# すべてのテストを実行
mix test

# 特定のアプリのテストを実行
mix test apps/shinkanki
mix test apps/shinkanki_web
```

### コード品質

```bash
# precommitチェック（コンパイル警告、フォーマット、テスト）
mix precommit
```

## デプロイ

Fly.ioへのデプロイに対応しています：

```bash
# Fly.ioにデプロイ
fly deploy
```

## ライセンス

All rights reserved.
