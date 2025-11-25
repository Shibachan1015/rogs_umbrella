# ワークツリー別作業分担表

> **作成日**: 2025-01-27
> **目的**: コンフリクトを避けながら、各ワークツリーで効率的に作業を進めるための指示書

---

## 📋 現在のTODOタスク

各ワークツリーに振り分けられた作業を効率的に進めるための指示書です。

---

## 🎯 ワークツリー別作業指示

### 1. `rogs-ui` ワークツリー（UI/UX担当）

**担当者**: UI/UX Specialist AI Agent

**作業内容**:

#### ✅ 優先度：高
1. **レスポンシブデザインの強化**
   - モバイル・タブレット最適化
   - ブレークポイントの統一と調整
   - タッチ操作の最適化
   - ファイル: `apps/*/assets/css/app.css`, `apps/*/lib/*/components/core_components.ex`

2. **アクセシビリティ改善**
   - キーボードナビゲーション対応
   - スクリーンリーダー対応（ARIA属性の追加）
   - WCAG準拠のコントラスト比確保
   - フォーカス管理の改善
   - ファイル: 全UIコンポーネント

3. **TRDSドキュメントの拡張**
   - ファイル: `docs/torii_resonance_design_system.md`
   - 追加内容:
     - ダークモード/ライトモードの切り替え指針
     - アクセシビリティ（a11y）ルール
     - WCAG準拠のコントラスト比ガイドライン
     - キーボードナビゲーション指針
     - レスポンシブデザインガイドライン
   - **注意**: このドキュメントは全アプリで参照されるため、慎重に編集

4. **共通UIコンポーネントの拡張**
   - `apps/*/lib/*/components/core_components.ex` の拡張
   - 新しいコンポーネントの追加
   - 既存コンポーネントの機能拡張
   - **注意**: 全アプリで使用されるため、後方互換性を保つ

**ブランチ**: `feature/new-ui` または適切なブランチ

**コンフリクト回避**:
- このワークツリーは `docs/torii_resonance_design_system.md` を独占的に編集
- CSSファイルの変更はこのワークツリーで一元管理
- `core_components.ex` の変更はこのワークツリーで一元管理
- 他のワークツリーはCSSや`core_components.ex`を直接編集しない

---

### 2. `rogs-shinkanki` ワークツリー（ゲームロジック担当）

**担当者**: Main Logic Developer

**作業内容**:

#### ✅ 優先度：高（ゲームプレイに必須）
1. **フェーズ表示UI実装**
   - ゲームフェーズ（Event, Discussion, Action, Demurrage, Life Update）の表示
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

2. **イベントカード表示UI**
   - イベントカードの表示とスタイリング
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

3. **才能カードUI**
   - 才能カードの表示とスタイリング
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

4. **共創プロジェクトカードUI**
   - 共創プロジェクトカードの表示とスタイリング
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

5. **プレイヤー役割選択画面**
   - 役割選択UIの実装
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

6. **エンディング画面**
   - ゲーム終了時のエンディング画面
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

7. **アクション確認UI**
   - アクション実行前の確認UI
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

#### ⚠️ 優先度：中（UX向上）
8. **ルーム管理UI**
   - ルーム作成・参加・退出UI
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

9. **カード詳細モーダル**
   - カードの詳細情報を表示するモーダル
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

10. **ゲーム履歴・ログ表示**
    - ゲームの進行履歴とログの表示
    - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

11. **コード整理**
    - 未使用関数の警告解消
    - `mock_game_history/0` と `mock_actions/0` の整理
    - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`

**ブランチ**: `feature/game-logic` または適切なブランチ

**コンフリクト回避**:
- `game_live.ex` のロジック部分のみ編集
- UIスタイル（CSSクラス）の変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼
- CSSを直接編集しない

---

### 3. `rogs-identity` ワークツリー（認証担当）

**担当者**: Identity Developer

**作業内容**:

#### ✅ 優先度：高
1. **認証UIにTRDS適用**
   - ログイン画面のTRDS適用
   - 登録画面のTRDS適用
   - パスワードリセット画面のTRDS適用
   - ファイル:
     - `apps/rogs_identity/lib/rogs_identity_web/live/user_live/login.ex`
     - `apps/rogs_identity/lib/rogs_identity_web/live/user_live/registration.ex`
     - `apps/rogs_identity/lib/rogs_identity_web/live/user_live/forgot_password.ex`
     - `apps/rogs_identity/lib/rogs_identity_web/live/user_live/reset_password.ex`
   - **注意**: CSSの変更は `rogs-ui` に依頼

**ブランチ**: `feature/identity-dev` または適切なブランチ

**コンフリクト回避**:
- 認証ロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼
- CSSを直接編集しない

---

### 4. `rogs-chat` ワークツリー（チャット担当）

**担当者**: Chat Developer

**作業内容**:

#### ✅ 優先度：高
1. **チャットUIにTRDS適用**
   - チャット画面のデザイン改善
   - メッセージ表示のTRDS適用
   - 入力フォームのTRDS適用
   - ファイル: `apps/rogs_comm/lib/rogs_comm_web/live/chat_live.ex`
   - **注意**: CSSの変更は `rogs-ui` に依頼

**ブランチ**: `feature/chat` または適切なブランチ

**コンフリクト回避**:
- チャットロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼
- CSSを直接編集しない

---

### 5. `rogs_umbrella` ワークツリー（メイン/マージ担当）

**担当者**: Integration Manager

**作業内容**:

#### ✅ 優先度：高
1. **全ワークツリーの同期**
   - 各ワークツリーの変更が完了したら `./sync_all.sh` を実行
   - 全ワークツリーの変更を `main` ブランチにマージ
   - コンフリクトがあれば解決

2. **デプロイ準備**
   - 全アプリのテストを実行
   - ビルドエラーの確認
   - デプロイ準備

**ブランチ**: `main`

**コンフリクト回避**:
- このワークツリーでは直接コードを編集しない
- マージと同期のみを行う
- 各ワークツリーの変更を取り込む

---

## 🔄 作業フロー

### ステップ1: 各ワークツリーで独立作業
1. `rogs-ui`: レスポンシブデザイン強化、アクセシビリティ改善、TRDSドキュメント拡張、共通UIコンポーネント拡張
2. `rogs-shinkanki`: フェーズ表示UI、イベントカード、才能カード、共創プロジェクトカード、プレイヤー役割選択、エンディング画面、アクション確認UI、ルーム管理UI、カード詳細モーダル、ゲーム履歴・ログ表示、コード整理
3. `rogs-identity`: 認証UIにTRDS適用（ログイン、登録、パスワードリセット画面）
4. `rogs-chat`: チャットUIにTRDS適用（チャット画面のデザイン改善）

### ステップ2: 同期とマージ
1. `rogs_umbrella` で `./sync_all.sh` を実行
2. 各ワークツリーの変更を `main` にマージ
3. コンフリクトがあれば解決

### ステップ3: 最終確認
1. 全アプリのテストを実行
2. ブラウザで各アプリの表示を確認
3. レスポンシブデザインの動作確認（モバイル・タブレット）
4. アクセシビリティの確認（キーボードナビゲーション、スクリーンリーダー）
5. 問題がなければ完了

---

## ⚠️ コンフリクト回避のルール

### 共有リソースの編集ルール

| リソース | 編集権限 | 備考 |
|---------|---------|------|
| `docs/torii_resonance_design_system.md` | `rogs-ui` のみ | 全アプリで参照されるため、一元管理 |
| `apps/*/assets/css/app.css` | `rogs-ui` のみ | UIスタイルは一元管理 |
| `apps/*/lib/*/components/core_components.ex` | `rogs-ui` のみ | 共通コンポーネントは一元管理 |
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
- [ ] TRDSドキュメントの拡張（ダーク/ライト指針、a11yルール、レスポンシブガイドライン）
- [ ] 共通UIコンポーネントの拡張
- [ ] CSSビルド確認
- [ ] 変更をコミット

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
- [ ] コード整理（未使用関数の警告解消）
- [ ] 変更をコミット

### `rogs-identity` ワークツリー
- [ ] 認証UIにTRDS適用（ログイン、登録、パスワードリセット画面）
- [ ] 変更をコミット

### `rogs-chat` ワークツリー
- [ ] チャットUIにTRDS適用（チャット画面のデザイン改善）
- [ ] 変更をコミット

### `rogs_umbrella` ワークツリー
- [ ] 全ワークツリーの同期
- [ ] 変更を `main` にマージ
- [ ] 全アプリのテスト実行

---

## 🚨 注意事項

1. **共有リソースの編集は慎重に**
   - `core_components.ex` や `app.css` の変更は全アプリに影響
   - 必ず `rogs-ui` ワークツリーで編集
   - `rogs-shinkanki`, `rogs-identity`, `rogs-chat` はCSSを直接編集しない

2. **UIスタイル変更の依頼**
   - `rogs-shinkanki`, `rogs-identity`, `rogs-chat` でUIスタイルの変更が必要な場合は、`rogs-ui` ワークツリーに依頼
   - `core_components.ex` の変更も `rogs-ui` に依頼

3. **ブランチの二重チェックアウト禁止**
   - 同じブランチを複数のワークツリーで同時にチェックアウトしない
   - 各ワークツリーは専用ブランチで作業

4. **依存関係の同期**
   - `mix.lock` が更新されたら、他のワークツリーで `mix deps.get` を実行

5. **コミット前の確認**
   - 各ワークツリーで `mix test apps/APP_NAME` を実行
   - ビルドエラーがないか確認
   - UI変更の場合はブラウザでの表示確認も実施

---

**最終更新**: 2025-01-27


