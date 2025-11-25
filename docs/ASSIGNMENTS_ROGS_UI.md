# rogs-ui ワークツリー作業指示

> **参照**: `docs/WORKTREE_ASSIGNMENTS.md` の詳細な作業分担表を確認してください

## 🎯 あなたの担当タスク

### ✅ 優先度：高

1. **レスポンシブデザインの強化**
   - モバイル最適化（タッチターゲットサイズ、スワイプジェスチャー）
   - タブレット最適化
   - ファイル: `apps/shinkanki_web/assets/css/app.css`

2. **アクセシビリティ改善**
   - キーボードナビゲーションの完全実装
   - スクリーンリーダー対応（ARIAラベルの追加、ライブリージョンの適切な使用）
   - WCAG準拠のコントラスト比確認
   - ファイル: `apps/shinkanki_web/assets/css/app.css`, `apps/shinkanki_web/lib/shinkanki_web_web/components/core_components.ex`

3. **TRDSドキュメントの拡張**
   - アクセシビリティ（a11y）ルールの詳細化
   - レスポンシブデザインのガイドライン追加
   - ファイル: `docs/torii_resonance_design_system.md`

### ⚠️ 優先度：中

4. **共通UIコンポーネントの拡張**
   - モーダルコンポーネントのTRDS対応
   - ローディングインジケーターのTRDS対応
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/core_components.ex`

## 🎨 あなたの特権

- **CSSファイルの独占編集権**: `apps/*/assets/css/app.css` はこのワークツリーのみが編集可能
- **共通コンポーネントの独占編集権**: `apps/*/lib/*/components/core_components.ex` はこのワークツリーのみが編集可能
- **TRDSドキュメントの独占編集権**: `docs/torii_resonance_design_system.md` はこのワークツリーのみが編集可能

## 📚 参考資料

- `docs/WORKTREE_ASSIGNMENTS.md` - 詳細な作業分担表
- `docs/torii_resonance_design_system.md` - TRDSデザインシステム

