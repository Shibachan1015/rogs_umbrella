# rogs-shinkanki ワークツリー作業指示

> **参照**: `docs/WORKTREE_ASSIGNMENTS.md` の詳細な作業分担表を確認してください

## 🎯 あなたの担当タスク

### ✅ 高優先度（ゲームプレイに必須）

1. **フェーズ表示UI実装**
   - イベント、相談、アクション、減衰、生命更新、判定の各フェーズ表示
   - フェーズ進行インジケーターと説明テキスト
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`, `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

2. **イベントカード表示UI**
   - イベントフェーズでのイベントカード表示
   - カード詳細モーダルと効果説明
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

3. **才能カードUI**
   - プレイヤーが持つ才能カードの表示
   - アクションカードへの重ね合わせUI（最大2枚）
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/live/game_live.ex`, `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

4. **共創プロジェクトカードUI**
   - プロジェクトカードの表示エリア
   - 進行状況表示と才能カードを捧げるUI
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

5. **プレイヤー役割選択画面**
   - 4つの役割（森の守り手、文化の継承者、コミュニティの灯火、空環エンジニア）の説明
   - 役割選択UIと色分け
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

6. **エンディング画面**
   - 5種類のエンディング（神々の祝福、浄化の兆し、揺らぎの未来、神々の嘆き、即時ゲームオーバー）
   - エンディングごとの専用デザインと統計表示
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

7. **アクション確認UI**
   - カード使用前の確認ダイアログ
   - 効果のプレビューとコスト確認
   - ファイル: `apps/shinkanki_web/lib/shinkanki_web_web/components/game_components.ex`

### ⚠️ 中優先度（UX向上）

8. **ルーム管理UI**
   - ルーム一覧画面とルーム作成モーダル
   - ルーム検索・フィルタ機能

9. **カード詳細モーダル**
   - カードクリック/ホバーで詳細表示
   - コスト、効果、使用可能条件の表示

10. **ゲーム履歴・ログ表示**
    - ターンごとの履歴表示
    - スクロール可能な履歴パネル

11. **コード整理**
    - 未使用関数の警告解消（`game_live.ex`の`mock_game_history/0`など）

## ⚠️ 重要な注意事項

- **CSSの直接編集は禁止**: UIスタイル（CSSクラス）の変更が必要な場合は `rogs-ui` ワークツリーに依頼してください
- **`core_components.ex` の編集は禁止**: 共通コンポーネントの変更は `rogs-ui` ワークツリーに依頼してください
- **編集可能なファイル**: `game_live.ex` のロジック部分、`game_components.ex` のゲーム固有コンポーネントのみ

## 📚 参考資料

- `docs/WORKTREE_ASSIGNMENTS.md` - 詳細な作業分担表
- `docs/torii_resonance_design_system.md` - TRDSデザインシステム

