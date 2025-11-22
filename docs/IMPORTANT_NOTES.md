# Rogs Umbrella 開発・運用における重要事項

本ドキュメントは、Git Worktreeを使用したUmbrellaプロジェクト開発において、開発効率と品質を維持するために特に重要と考えられるポイントをまとめたものです。

## 1. Git Worktree 運用の鉄則

### 🚫 ブランチの二重チェックアウト禁止
Git Worktreeの仕様上、**「同じブランチを複数のWorktreeで同時にチェックアウトすること」はできません**。
- **対策**: 各Worktreeは必ず専用の役割（Identity, Chat, UIなど）を持ち、それぞれ異なるブランチ（`feature/auth`, `feature/chat` など）で作業することを徹底してください。
- **例外**: `main` ブランチを見たい場合は、`rogs_umbrella` ディレクトリで確認するか、各Worktreeで `git merge main` して取り込んで確認します。

### 🔄 依存関係の同期 (`mix.lock`)
すべてのWorktreeは `mix.lock` を共有（Git管理下）していますが、物理的なファイルは各ディレクトリに存在します。
- **注意点**: あるWorktreeで新しいライブラリを追加（`mix deps.get`）して `mix.lock` が更新された場合、**他のWorktreeではその変更が即座には反映されません**。
- **アクション**: 他のWorktreeに切り替えた際、ビルドエラーが出たらまず `git pull` して `mix deps.get` を実行する癖をつけてください。

---

## 2. Phoenix Umbrella Project の落とし穴

### ⚙️ 設定ファイル (`config/`) は「全アプリ共通」
Umbrellaプロジェクトでは、`config/config.exs` や `config/dev.exs` は**全アプリケーションで共有**されます。
- **リスク**: `apps/rogs_identity` 用の設定を書いたつもりでも、`apps/rogs_comm` に影響を与える可能性があります。
- **ベストプラクティス**: 設定ファイル内では、どのアプリの設定なのか明確にするため、コメントやセクション分けを丁寧に行ってください。
  ```elixir
  # === Rogs Identity Configuration ===
  config :rogs_identity, ...

  # === Rogs Comm Configuration ===
  config :rogs_comm, ...
  ```

### 🔗 アプリ間連携の境界線
- **原則**: `apps/` 配下の各アプリは、独立性を保つのが理想です。
- **注意**: `rogs_shinkanki_web` から `rogs_identity` のコンテキストを呼び出すのはOKですが、逆（IdentityがWebに依存）や、循環参照（互いに呼び合う）は避けてください。
- **推奨**: アプリ間のやり取りは、明確な公開関数（Context）を通じてのみ行うように設計してください。

---

## 3. 開発効率と品質

### 🎨 UI/Component の変更フロー
UI変更は影響範囲が広いため、以下のフローを推奨します。
1. **`rogs-ui` Worktree** で共通コンポーネント（`core_components.ex`）やCSSを修正。
2. 修正を `main` にマージ。
3. 各機能開発のWorktree（`rogs-identity` など）で `main` をマージして、デザイン崩れがないか確認。

### 🧪 テスト実行のスコープ
Umbrellaプロジェクトのルートで `mix test` を実行すると、全アプリのテストが走ります。
- **効率化**: `rogs_identity` の開発中は、ルートで `mix test apps/rogs_identity` と指定するか、`apps/rogs_identity` ディレクトリに移動してテストを実行することで、フィードバックループを高速化できます。

---

## 4. トラブルシューティング

### 「モジュールが見つからない」と言われたら
Worktreeを切り替えた直後によく発生します。
1. `mix deps.get` （依存関係の取得）
2. `mix compile` （再コンパイル）
この2つを実行してみてください。

### データベースのマイグレーション
各アプリがそれぞれのマイグレーションファイルを持っていますが、実行はルートから一括で行うのが基本です。
- コマンド: `mix ecto.migrate`
- これにより、全アプリ（`rogs_identity`, `rogs_comm` など）の保留中のマイグレーションが適切な順序で実行されます。

