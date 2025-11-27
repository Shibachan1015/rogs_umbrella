# rogs-identity ワークツリー作業指示

> **参照**: `docs/WORKTREE_ASSIGNMENTS.md` の詳細な作業分担表を確認してください

## 🎯 あなたの担当タスク

### ⚠️ 中優先度（UX向上）

1. **認証UIにTRDS適用**
   - ログイン、登録、パスワードリセット画面のMiyabiテーマ適用
   - ファイル: `apps/rogs_identity/lib/rogs_identity_web/controllers/user_auth_html/` 配下
   - **注意**: TRDSのトークンとコンポーネントを使用（`rogs-ui` で定義済み）

2. **認証UIの表示確認**
   - `http://localhost:4001` で認証画面を開く
   - TRDSスタイルが正しく適用されているか確認
   - 問題があれば `rogs-ui` ワークツリーに報告

## ⚠️ 重要な注意事項

- **CSSの直接編集は禁止**: UIスタイルの変更が必要な場合は `rogs-ui` ワークツリーに依頼してください
- **`core_components.ex` の編集は禁止**: 共通コンポーネントの変更は `rogs-ui` ワークツリーに依頼してください
- **編集可能なファイル**: 認証ロジックのみ編集可能

## 📚 参考資料

- `docs/WORKTREE_ASSIGNMENTS.md` - 詳細な作業分担表
- `docs/torii_resonance_design_system.md` - TRDSデザインシステム

