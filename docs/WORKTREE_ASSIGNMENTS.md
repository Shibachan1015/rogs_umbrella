# ワークツリー別作業分担表

> **作成日**: 2025-01-XX
> **目的**: コンフリクトを避けながら、各ワークツリーで効率的に作業を進めるための指示書

---

## 📋 現在のTODOタスク

1. **TRDSドキュメントへダーク/ライト指針とa11yルール追記**
2. **未コミットの変更を確認・整理（マージコンフリクト解決分を含む）**
3. **CSSビルド確認とブラウザでの表示確認**
4. **esbuild/Tailwindバージョン警告の解消（必要に応じて）**

---

## 🎯 ワークツリー別作業指示

### 1. `rogs-ui` ワークツリー（UI/UX担当）

**担当者**: UI/UX Specialist AI Agent

**作業内容**:

#### ✅ 優先度：高
1. **TRDSドキュメントの拡張**
   - ファイル: `docs/torii_resonance_design_system.md`
   - 追加内容:
     - ダークモード/ライトモードの切り替え指針
     - アクセシビリティ（a11y）ルール
     - WCAG準拠のコントラスト比ガイドライン
     - キーボードナビゲーション指針
   - **注意**: このドキュメントは全アプリで参照されるため、慎重に編集

2. **CSSビルド確認**
   - `apps/shinkanki_web/assets/css/app.css` のビルド確認
   - `mix assets.build` または `npm run build` の実行
   - ビルドエラーの確認と修正

3. **未コミットの変更を整理・コミット**
   - マージコンフリクト解決分の確認
   - `apps/shinkanki_web/assets/css/app.css` の変更をコミット
   - `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex` の変更をコミット
   - コミットメッセージ: `fix: resolve merge conflicts in CSS and game_live.ex`

#### ⚠️ 優先度：中
4. **esbuild/Tailwindバージョン警告の解消（必要に応じて）**
   - 警告は出ているが動作には問題なし
   - 必要に応じて `mix esbuild.install` / `mix tailwind.install` を実行
   - **注意**: バージョン変更は全アプリに影響するため、慎重に判断

**ブランチ**: `feature/new-ui` (現在のブランチ)

**コンフリクト回避**:
- このワークツリーは `docs/torii_resonance_design_system.md` を独占的に編集
- CSSファイルの変更はこのワークツリーで一元管理
- 他のワークツリーはCSSを直接編集しない

---

### 2. `rogs-shinkanki` ワークツリー（ゲームロジック担当）

**担当者**: Main Logic Developer

**作業内容**:

#### ✅ 優先度：高
1. **ゲームUIの表示確認**
   - `http://localhost:4000` でゲーム画面を開く
   - CSSが正しく適用されているか確認
   - プロジェクトステージ、ライフインデックスオーブ、アクションリボンなどの表示確認
   - 問題があれば `rogs-ui` ワークツリーに報告

2. **未使用関数の警告解消**
   - `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`
   - `mock_game_history/0` と `mock_actions/0` が未使用
   - 削除するか、将来の使用を見据えて残すか判断
   - **注意**: 削除する場合は、他の場所で使用されていないか確認

**ブランチ**: `feature/game-logic` または適切なブランチ

**コンフリクト回避**:
- `game_live.ex` のロジック部分のみ編集
- UIスタイル（CSSクラス）の変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

---

### 3. `rogs-identity` ワークツリー（認証担当）

**担当者**: Identity Developer

**作業内容**:

#### ✅ 優先度：中
1. **認証UIの表示確認**
   - `http://localhost:4001` で認証画面を開く
   - TRDSスタイルが正しく適用されているか確認
   - ログイン、登録、パスワードリセット画面の確認
   - 問題があれば `rogs-ui` ワークツリーに報告

2. **未コミットの変更を整理・コミット**
   - `apps/rogs_identity/` 配下の変更を確認
   - TRDS適用による変更をコミット
   - コミットメッセージ: `style: apply TRDS to identity UI components`

**ブランチ**: `feature/identity` または適切なブランチ

**コンフリクト回避**:
- 認証ロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

---

### 4. `rogs-chat` ワークツリー（チャット担当）

**担当者**: Chat Developer

**作業内容**:

#### ✅ 優先度：中
1. **チャットUIの表示確認**
   - `http://localhost:4002` でチャット画面を開く
   - TRDSスタイルが正しく適用されているか確認
   - メッセージ表示、入力フォームの確認
   - 問題があれば `rogs-ui` ワークツリーに報告

2. **未コミットの変更を整理・コミット**
   - `apps/rogs_comm/` 配下の変更を確認
   - TRDS適用による変更をコミット
   - コミットメッセージ: `style: apply TRDS to chat UI components`

**ブランチ**: `feature/chat` または適切なブランチ

**コンフリクト回避**:
- チャットロジックのみ編集
- UIスタイルの変更は `rogs-ui` に依頼
- `core_components.ex` の変更は `rogs-ui` に依頼

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
1. `rogs-ui`: TRDSドキュメント拡張、CSSビルド確認、変更コミット
2. `rogs-shinkanki`: ゲームUI表示確認、未使用関数の整理
3. `rogs-identity`: 認証UI表示確認、変更コミット
4. `rogs-chat`: チャットUI表示確認、変更コミット

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
| `config/config.exs` | 各ワークツリー | アプリ固有の設定のみ編集、コメントで明示 |
| `mix.lock` | 自動生成 | 変更時は他ワークツリーで `mix deps.get` を実行 |

### ブランチ運用ルール

- 各ワークツリーは専用のブランチで作業
- 同じブランチを複数のワークツリーで同時にチェックアウトしない
- `main` ブランチは `rogs_umbrella` でのみ使用

---

## 📝 チェックリスト

### `rogs-ui` ワークツリー
- [ ] TRDSドキュメントにダーク/ライト指針を追記
- [ ] TRDSドキュメントにa11yルールを追記
- [ ] CSSビルド確認
- [ ] マージコンフリクト解決分をコミット
- [ ] esbuild/Tailwindバージョン警告の解消（必要に応じて）

### `rogs-shinkanki` ワークツリー
- [ ] ゲームUIの表示確認
- [ ] 未使用関数の警告解消
- [ ] 変更をコミット

### `rogs-identity` ワークツリー
- [ ] 認証UIの表示確認
- [ ] 変更をコミット

### `rogs-chat` ワークツリー
- [ ] チャットUIの表示確認
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

2. **ブランチの二重チェックアウト禁止**
   - 同じブランチを複数のワークツリーで同時にチェックアウトしない

3. **依存関係の同期**
   - `mix.lock` が更新されたら、他のワークツリーで `mix deps.get` を実行

4. **コミット前の確認**
   - 各ワークツリーで `mix test apps/APP_NAME` を実行
   - ビルドエラーがないか確認

---

**最終更新**: 2025-01-XX


