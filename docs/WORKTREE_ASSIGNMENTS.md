# ワークツリー別作業分担表

> **作成日**: 2025-01-XX
> **最終更新**: 2025-01-XX
> **目的**: コンフリクトを避けながら、各ワークツリーで効率的に作業を進めるための指示書

---

## 🎯 ワークツリー別作業指示

### 1. `rogs-ui` ワークツリー（UI/UX担当）

**担当者**: UI/UX Specialist AI Agent
**ブランチ**: `feature/new-ui`

**役割**: TRDS（Torii Resonance Design System）の策定・共通スタイル実装・コアコンポーネント管理

#### ✅ 優先度：高

1. **レスポンシブデザインの強化**
   - モバイル最適化（タッチターゲットサイズ、スワイプジェスチャー）
   - タブレット最適化
   - ファイル: `apps/shinkanki_web/assets/css/app.css`
   - **注意**: 全アプリに影響するため、慎重に実装

2. **アクセシビリティ改善**
   - キーボードナビゲーションの完全実装
   - スクリーンリーダー対応（ARIAラベルの追加、ライブリージョンの適切な使用）
   - WCAG準拠のコントラスト比確認
   - ファイル: `apps/shinkanki_web/assets/css/app.css`, `apps/shinkanki_web/lib/shinkanki_web_web/components/core_components.ex`
   - **注意**: 全アプリで使用される共通コンポーネントの改善

3. **TRDSドキュメントの拡張**
   - アクセシビリティ（a11y）ルールの詳細化
   - レスポンシブデザインのガイドライン追加
   - ファイル: `docs/torii_resonance_design_system.md`

#### ⚠️ 優先度：中

4. **共通UIコンポーネントの拡張**
   - モーダルコンポーネントのTRDS対応
   - ローディングインジケーターのTRDS対応
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/core_components.ex`

**コンフリクト回避**:
- このワークツリーは `docs/torii_resonance_design_system.md` を独占的に編集
- CSSファイルの変更はこのワークツリーで一元管理
- `core_components.ex` の変更はこのワークツリーで一元管理
- 他のワークツリーはCSSや共通コンポーネントを直接編集しない

---

### 2. `rogs-shinkanki` ワークツリー（ゲームロジック担当）

**担当者**: Main Logic Developer
**ブランチ**: `feature/game-logic` または適切なブランチ

**役割**: ゲームロジック・ゲームUI本体（`apps/shinkanki` & `apps/shinkanki_web`）

#### ✅ 優先度：高（ゲームプレイに必須）

1. **フェーズ表示UI実装**
   - イベント、相談、アクション、減衰、生命更新、判定の各フェーズ表示
   - フェーズ進行インジケーターと説明テキスト
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`, `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: UIスタイル（CSSクラス）の追加が必要な場合は `rogs-ui` に依頼

2. **イベントカード表示UI**
   - イベントフェーズでのイベントカード表示
   - カード詳細モーダルと効果説明
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `event_card` コンポーネントの拡張

3. **才能カードUI**
   - プレイヤーが持つ才能カードの表示
   - アクションカードへの重ね合わせUI（最大2枚）
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`, `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `talent_card` コンポーネントの拡張、`action_card_with_talents` の改善

4. **共創プロジェクトカードUI**
   - プロジェクトカードの表示エリア
   - 進行状況表示と才能カードを捧げるUI
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `project_card` コンポーネントの拡張、`project_contribute_modal` の改善

5. **プレイヤー役割選択画面**
   - 4つの役割（森の守り手、文化の継承者、コミュニティの灯火、空環エンジニア）の説明
   - 役割選択UIと色分け
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `role_selection_screen` コンポーネントの実装・改善

6. **エンディング画面**
   - 5種類のエンディング（神々の祝福、浄化の兆し、揺らぎの未来、神々の嘆き、即時ゲームオーバー）
   - エンディングごとの専用デザインと統計表示
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `ending_screen` コンポーネントの実装・改善

7. **アクション確認UI**
   - カード使用前の確認ダイアログ
   - 効果のプレビューとコスト確認
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `action_confirm_modal` コンポーネントの改善

#### ⚠️ 優先度：中（UX向上）

8. **ルーム管理UI**
   - ルーム一覧画面とルーム作成モーダル
   - ルーム検索・フィルタ機能
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/` (新規LiveView作成)
   - **注意**: `rogs_comm` のルーム機能と連携

9. **カード詳細モーダル**
   - カードクリック/ホバーで詳細表示
   - コスト、効果、使用可能条件の表示
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`
   - **注意**: `card_detail_modal` コンポーネントの実装・改善

10. **ゲーム履歴・ログ表示**
    - ターンごとの履歴表示
    - スクロール可能な履歴パネル
    - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`, `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

11. **コード整理**
    - 未使用関数の警告解消（`game_live.ex`の`mock_game_history/0`など）
    - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

**コンフリクト回避**:
- `game_live.ex` のロジック部分のみ編集
- `game_components.ex` のゲーム固有コンポーネントのみ編集
- UIスタイル（CSSクラス）の変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

---

### 3. `rogs-identity` ワークツリー（認証担当）

**担当者**: Identity Developer
**ブランチ**: `feature/identity` または適切なブランチ

**役割**: 認証UI（`apps/rogs_identity`）

#### ⚠️ 優先度：中（UX向上）

1. **認証UIにTRDS適用**
   - ログイン、登録、パスワードリセット画面のMiyabiテーマ適用
   - ファイル: `apps/rogs_identity/lib/rogs_identity_web/controllers/user_auth_html/` 配下
   - **注意**: TRDSのトークンとコンポーネントを使用（`rogs-ui` で定義済み）
   - **注意**: CSSの直接編集は `rogs-ui` に依頼

2. **認証UIの表示確認**
   - `http://localhost:4001` で認証画面を開く
   - TRDSスタイルが正しく適用されているか確認
   - 問題があれば `rogs-ui` ワークツリーに報告

**コンフリクト回避**:
- 認証ロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

---

### 4. `rogs-chat` ワークツリー（チャット担当）

**担当者**: Chat Developer
**ブランチ**: `feature/chat` または適切なブランチ

**役割**: チャットUI（`apps/rogs_comm`）

#### ⚠️ 優先度：中（UX向上）

1. **チャットUIにTRDS適用**
   - チャット画面のデザイン改善
   - 和紙風メッセージ背景
   - ファイル: `apps/rogs_comm/lib/rogs_comm_web/live/chat_live.ex`
   - **注意**: TRDSのトークンとコンポーネントを使用（`rogs-ui` で定義済み）
   - **注意**: CSSの直接編集は `rogs-ui` に依頼

2. **チャットUIの表示確認**
   - `http://localhost:4002` でチャット画面を開く
   - TRDSスタイルが正しく適用されているか確認
   - 問題があれば `rogs-ui` ワークツリーに報告

**コンフリクト回避**:
- チャットロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

---

### 5. `rogs_umbrella` ワークツリー（メイン/マージ担当）

**担当者**: Integration Manager
**ブランチ**: `main`

**役割**: 全ワークツリーの同期・マージ・デプロイ準備

#### ✅ 優先度：高

1. **全ワークツリーの同期**
   - 各ワークツリーの変更が完了したら `./sync_all.sh` を実行
   - 全ワークツリーの変更を `main` ブランチにマージ
   - コンフリクトがあれば解決

2. **デプロイ準備**
   - 全アプリのテストを実行
   - ビルドエラーの確認
   - デプロイ準備

**コンフリクト回避**:
- このワークツリーでは直接コードを編集しない
- マージと同期のみを行う
- 各ワークツリーの変更を取り込む

---

## 🔄 作業フロー

### ステップ1: 各ワークツリーで独立作業

1. **`rogs-ui`**: レスポンシブデザイン強化、アクセシビリティ改善、TRDSドキュメント拡張
2. **`rogs-shinkanki`**: ゲームUI実装（フェーズ表示、イベントカード、才能カード、プロジェクトカード、役割選択、エンディング、アクション確認、ルーム管理、カード詳細、ゲーム履歴）
3. **`rogs-identity`**: 認証UIにTRDS適用
4. **`rogs-chat`**: チャットUIにTRDS適用

### ステップ2: 同期とマージ

1. `rogs_umbrella` で `./sync_all.sh` を実行
2. 各ワークツリーの変更を `main` にマージ
3. コンフリクトがあれば解決

### ステップ3: 最終確認

1. 全アプリのテストを実行
2. ブラウザで各アプリの表示を確認
3. 問題がなければ完了

---

## ⚠️ コンフリクト回避のルール

### 共有リソースの編集ルール

| リソース | 編集権限 | 備考 |
|---------|---------|------|
| `docs/torii_resonance_design_system.md` | `rogs-ui` のみ | 全アプリで参照されるため、一元管理 |
| `apps/*/assets/css/app.css` | `rogs-ui` のみ | UIスタイルは一元管理 |
| `apps/*/lib/*/components/core_components.ex` | `rogs-ui` のみ | 共通コンポーネントは一元管理 |
| `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex` | `rogs-shinkanki` のみ | ゲーム固有コンポーネント |
| `config/config.exs` | 各ワークツリー | アプリ固有の設定のみ編集、コメントで明示 |
| `mix.lock` | 自動生成 | 変更時は他ワークツリーで `mix deps.get` を実行 |

### ブランチ運用ルール

- 各ワークツリーは専用のブランチで作業
- 同じブランチを複数のワークツリーで同時にチェックアウトしない
- `main` ブランチは `rogs_umbrella` でのみ使用

---

## 📝 チェックリスト

### `rogs-ui` ワークツリー
- [ ] レスポンシブデザインの強化（モバイル・タブレット最適化）
- [ ] アクセシビリティ改善（キーボードナビゲーション、スクリーンリーダー対応、WCAG準拠）
- [ ] TRDSドキュメントの拡張（a11yルール、レスポンシブガイドライン）
- [ ] 共通UIコンポーネントの拡張（モーダル、ローディングインジケーター）

### `rogs-shinkanki` ワークツリー
- [ ] フェーズ表示UI実装
- [ ] イベントカード表示UI
- [ ] 才能カードUI
- [ ] 共創プロジェクトカードUI
- [ ] プレイヤー役割選択画面
- [ ] エンディング画面
- [ ] アクション確認UI
- [ ] ルーム管理UI
- [ ] カード詳細モーダル
- [ ] ゲーム履歴・ログ表示
- [ ] 未使用関数の警告解消

### `rogs-identity` ワークツリー
- [ ] 認証UIにTRDS適用（ログイン、登録、パスワードリセット）
- [ ] 認証UIの表示確認

### `rogs-chat` ワークツリー
- [ ] チャットUIにTRDS適用
- [ ] チャットUIの表示確認

### `rogs_umbrella` ワークツリー
- [ ] 全ワークツリーの同期
- [ ] 変更を `main` にマージ
- [ ] 全アプリのテスト実行

---

## 🚨 注意事項

1. **共有リソースの編集は慎重に**
   - `core_components.ex` や `app.css` の変更は全アプリに影響
   - 必ず `rogs-ui` ワークツリーで編集

2. **ブランチの二重チェックアウト禁止**
   - 同じブランチを複数のワークツリーで同時にチェックアウトしない

3. **依存関係の同期**
   - `mix.lock` が更新されたら、他のワークツリーで `mix deps.get` を実行

4. **コミット前の確認**
   - 各ワークツリーで `mix test apps/APP_NAME` を実行
   - ビルドエラーがないか確認

5. **UIスタイルの変更依頼**
   - `rogs-shinkanki`, `rogs-identity`, `rogs-chat` はCSSを直接編集しない
   - 必要なスタイル変更は `rogs-ui` に依頼

---

**最終更新**: 2025-01-XX
