# Claude Code 設定

## 言語設定
- 常に日本語で回答してください
- 質問や確認も日本語で行ってください
- コードのコメントは英語のままで構いません
- エラーメッセージの説明は日本語で行ってください

---

# プロジェクト概要（神環記 / Shinkanki）

リアルタイムマルチプレイヤーカードゲーム。Elixir/Phoenix Umbrella構成。

## アプリ構成
```
shinkanki_web（UI層・Phoenix LiveView）
  ├→ rogs_identity（認証・ユーザー管理）
  ├→ rogs_comm（ルーム・チャット）
  └→ shinkanki（ゲームロジック）
```

## デプロイ
- Fly.io: `rogs-umbrella.fly.dev`
- 独自ドメイン: `rogs.live`（ムームードメインでDNS設定済み）
- GitHub Actions で自動デプロイ（`.github/workflows/fly.yml`）

## ポート（開発環境）
- ShinkankiWeb: 4000
- RogsIdentity: 4001
- RogsComm: 4002

---

# 作業履歴

## 2024-12-13 セッション

### 完了した作業
1. **Google OAuth修正**: `.env` の環境変数が読み込まれない問題を修正
2. **UI修正**: パラメータプレビューの数字色を `text-sumi`（黒）→ `text-gray-200`（明るいグレー）に変更
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
3. **Fly.ioデプロイ設定**:
   - Dockerfile作成（Elixir 1.16.2, OTP 26.2.4）
   - fly.toml設定（PORT=8080, region=nrt）
   - GitHub Actionsワークフロー作成
   - 独自ドメイン `rogs.live` のSSL証明書設定

### 検出されたバグ・問題
1. **マイグレーションエラー（重大）**:
   - `apps/shinkanki/priv/repo/migrations/20251202144310_create_page_annotations.exs`
   - `users` テーブルを参照しているが、`shinkanki` DBには存在しない（`rogs_identity` にある）

2. **未使用alias（軽度）**:
   - `apps/rogs_identity/lib/rogs_identity_web/controllers/oauth_controller.ex:6`
   - `alias RogsIdentityWeb.UserAuth` が未使用

3. **到達不能コード（中度）**:
   - `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex:1956`
   - `{:error, reason}` パターンは `execute_hitoyo_phase` が常に `{:ok, _, _}` を返すためマッチしない

4. **マイグレーション重複**:
   - 7テーブルが `shinkanki`, `rogs_identity`, `rogs_comm` に空定義で重複
   - 対象: `game_sessions`, `players`, `action_cards`, `event_cards`, `collaborative_projects`, `game_actions`, `turn_states`

### Umbrella構造の分析結果
- **活かされている（70%）**: 関心の分離、コード再利用、テスト独立性
- **活かされていない**: 独立デプロイ（全アプリが同一DB）、マイグレーション管理
- **結論**: 実質モノリス。現段階ではUmbrellaのままで十分。マイクロサービス化は不要。

### 追加で完了した作業
5. **マイグレーション整理**:
   - 空のマイグレーション14ファイル削除（`rogs_comm`, `rogs_identity` から各7ファイル）
   - `page_annotations` の外部キー制約を修正（`users` テーブルはDBをまたぐため削除）
6. **コード警告修正**:
   - 未使用alias `RogsIdentityWeb.UserAuth` を削除
   - 到達不能コード `{:error, reason}` を削除
7. **UI層整理（軽微）**:
   - `router.ex` にドメイン境界のコメント追加

### 未完了・保留
1. **Fly.ioデプロイ**: 起動時クラッシュ（`Runtime terminating during boot`）
   - 原因: 複数Endpointの設定問題の可能性
   - 対応: config/runtime.exs で ShinkankiWebWeb.Endpoint のみ起動するよう設定済み

---

# 技術メモ

## Fly.io関連
- シークレット設定済み: `SECRET_KEY_BASE`, `DATABASE_URL`, `PHX_HOST`
- DNS: A/AAAAレコードでムームードメインからFly.ioへ
- SSL: Let's Encrypt自動発行

## 本番起動の設定
- `PHX_SERVER=true` で `ShinkankiWebWeb.Endpoint` のみ起動
- 他のEndpointは本番では起動しない（config/runtime.exs で設定）

## サーバー起動コマンド（開発）
```bash
# 環境変数付きで起動
GOOGLE_CLIENT_ID="..." GOOGLE_CLIENT_SECRET="..." mix phx.server

# ポート使用中の場合
lsof -ti:4000,4001,4002 | xargs kill -9
```
