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

# オープンイシュー

## 重大（ゲームプレイに影響）

1. **モバイル画面でカードが見えない（重大）**
   - 状態: ✅ 修正済み（2025-12-16）
   - 問題: ゲーム画面下部のカードがモバイルデバイスで完全に見えない
   - 修正内容:
     - Bottom Handをモバイルで`fixed`位置に変更（画面下部に固定）
     - `max-h-[35vh]`で高さ制限、スクロール可能
     - メインゲームエリアに`pb-48`のパディング追加
     - Action Logボタン位置を`bottom-[40vh]`に調整

## 中度

2. **ヒーロー画像が2.1MB**
   - 状態: ✅ 修正済み（2025-12-16）
   - 問題: ランディングページのヒーロー画像が大きすぎる
   - 修正内容: PNG → WebP変換で 2.1MB → 190KB（90%削減）

## セキュリティ修正（2025-12-16）

- ✅ OAuth リダイレクト検証の追加（Open Redirect対策）
- ✅ チャット検索XSS脆弱性の修正（HTMLエスケープ追加）
- ✅ DB SSL設定の環境変数化（DATABASE_SSL=trueで有効化可能）
- ✅ 開発バイパス認証の安全強化（コンパイル時決定、本番では無効）
- ✅ Cookie SameSite=Strict に変更
- ✅ レート制限の導入（チャット: 60秒で10回まで）
- ✅ メッセージ長制限の追加（最大5000文字）

## 軽度（技術的負債）

3. **マイグレーション重複**
   - 状態: 保留
   - 問題: 7テーブルが複数アプリに空定義で重複

## 機能追加・コンテンツ

4. **意見交換ページ / SNS機能**
   - 状態: ✅ 基本実装完了（2025-12-16）
   - 実装内容: 「神議りの間」チャンネル式フォーラム
   - URL: https://rogs.live/kamihakari
   - チャンネル:
     - #祈願（機能要望）
     - #浄化（バグ報告）
     - #談話（雑談）
     - #神託（お知らせ）
   - 未実装: 画像投稿機能（S3/R2連携が必要）
   - ~~**イシュー**: 文字色が暗すぎて見えにくい~~ → ✅ 修正済み（2025-12-16）
     - 修正: CSSの未定義変数を明示的なクリーム/ベージュ色（#f5f0e6, #d4cfc5, #b0a89a）に変更
   - ~~**イシュー**: モバイル（iPhone）でハンバーガーメニューが表示されない~~ → ✅ 修正済み（2025-12-16）
     - 原因: ハンバーガーボタンがログイン時の `else` 条件内にあり、ログイン状態では表示されなかった
     - 修正: ハンバーガーボタンをログイン条件の外に移動
   - ~~**イシュー**: ランディングページからログイン状態で神議りの間に入ると認証されない~~ → ✅ 修正済み（2025-12-16）
     - 原因: クッキー名の不一致（`_shinkanki_web_user_remember_me` vs `_rogs_identity_web_user_remember_me`）
     - 修正: クッキー名を統一、SameSite=Strict に変更

5. **神々の画像作成**
   - 状態: 未着手
   - 内容: 神々のイラストを作成してアップロード

6. **BGM・音楽制作**
   - 状態: 未着手
   - 内容: ゲーム用のBGMや音楽を作成

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
