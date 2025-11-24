# Torii Resonance Design System (TRDS)

> **Purpose:** Provide a unified, modern aesthetic for 神環記 (Shinkanki) products by blending traditional Miyabi motifs with contemporary, cinematic storytelling. This document is written so that AIエージェント (including this assistant) can consistently apply the system across Phoenix LiveView templates, Tailwind/CSS, and shared components.

---

## 1. Design Pillars

| Pillar | 説明 | 実装要点 |
| --- | --- | --- |
| **Torii Silhouette** | 縦ライン・トランスルーセントな層で「門」を表し、神域へ入る体験を演出。 | 背景に縦グラデ/ライン、絶対配置で透明度 0.05〜0.15 の装飾。 |
| **Resonant Glow** | 金箔・和紙の反射を想起させる柔らかな光。 | `var(--color-landing-gold)` をグラデ/ボーダーで多用、box-shadow で発光。 |
| **Aurora Nightfall** | 深い藍〜煤色のグラデによる夜の静謐さ。 | `--color-midnight` / `--color-deep-navy` を背景のベースに。 |
| **Miyabi Motion** | 緩やかな浮遊・フェードで呼吸感を持たせる。 | `fade-in`, `float`, `scrollPulse` などのアニメーションユーティリティを流用。 |

---

## 2. Token Map

| Token | CSS 変数 (app.css) | Tailwind / Utility 置き換え |
| --- | --- | --- |
| Primary Surface | `--color-midnight`, `--color-deep-navy` | `bg-[var(--color-midnight)]` |
| Accent Gold | `--color-landing-gold` | `text-[var(--color-landing-gold)]`, `border-[var(--color-landing-gold)]` |
| Pale Washi | `--color-landing-pale` | `text-[var(--color-landing-pale)]`, `bg-[var(--color-landing-pale)]/10` |
| Silver Secondary | `--color-landing-silver` | `text-[var(--color-landing-silver)]` |
| Body Text | `--color-landing-text-primary` | `text-[var(--color-landing-text-primary)]` |
| Muted Text | `--color-landing-text-secondary` | `text-[var(--color-landing-text-secondary)]` |
| Glow Shadow | `0 20px 60px rgba(0, 0, 0, 0.25)` + `0 0 25px rgba(212, 175, 55, 0.35)` | `shadow-[0_20px_60px_rgba(0,0,0,0.25)]` + custom class |

**Typography:**
- Display / Hero: 明朝 4rem〜 + letter-spacing 0.3–0.5em。
- Body: 明朝 1rem / line-height 1.9。
- System UI (小要素): Inter / メイリオ 0.8–0.9rem, letter-spacing 0.2em。

---

## 3. Component Guidelines

### 3.1 Layout Containers
```heex
<section class="landing-section" aria-labelledby="...">
  <h2 class="section-title">...</h2>
  ...
</section>
```
- `landing-section` と `section-title` を再利用。
- 余白: セクション上部 6rem / 下部 4rem (モバイル 4rem/3rem)。

### 3.2 Cards (Concept / Play)
- 親に `concept-card` or `play-card` を割り当てる。
- `concept-card` = ガラス風 (`rgba(26,31,46,0.55)` + border gold)＋hoverで `transform -6px`。
- `play-card` = 透明ボーダー + hover border gold。

### 3.3 Buttons
| Variant | Class / 説明 |
| --- | --- |
| Solid CTA | `cta-button cta-solid` (金色フィル + hover で前面にゴールド) |
| Outline CTA | `cta-button cta-outline` (セカンダリテキスト + hoverで金色ライン) |
| Navbar CTA | `landing-cta` (小型 pill, header用) |

### 3.4 Decorative Layers
- `torii-lines`: 中央縦線2本。HSV = 金グラデ、opacity <= 0.15。
- Noise overlay: `landing-body::before` を流用。
- Scroll indicator: `scrollPulse` animation (keyframes定義済み)。

---

## 4. Implementation Checklist (for AI Agents)

1. **レイアウト/コンテンツ**
   - `landing-body`, `landing-header`, `landing-section` などのユーティリティクラスを使用。
   - 新規ページをTRDSへ合わせる際は、既存セクション構造を踏襲 (Hero → Content → Cards → CTA)。

2. **CSS/Tailwind**
   - CSS変数は `app.css` にあるTRDSトークンを必ず参照。新しい色を追加する場合は `:root` に追記。
   - Tailwindクラスで `text-[color]` などを使う場合、`tailwind.config.js` の `content` に対象ファイルが含まれているか確認。

3. **コンポーネント**
   - LiveComponent / CoreComponent で `class` をリスト連結する際は Phoenix 用 `[@class ...]` 形式 or `Enum.join/` などで string化。
   - CTA・カードなど TRDSコンポーネント化が必要な場合、`landing_components.ex` のような専用モジュールを将来的に検討。

4. **アクセシビリティ**
   - `aria-label`, `aria-labelledby`, `role` を Hero/Section/Card で適切に設定（例: `<section aria-labelledby="concept-title">`）。
   - コントラスト: ゴールド (#d4af37) on Midnight (#0f1419) で 4.5:1 を満たす。必要に応じ `opacity` を調整。

5. **動的コンテンツ**
   - LiveViewで動的にリストレンダリングする場合は `landing-section` などのクラスを wrap して TRDS 見た目を維持。
   - 背景装飾 (`torii-lines`, noise) は `:global` CSS で共用可。 ゲームUI / ロビーも TRDS トーンへ合わせていく。

---

## 5. 拡張計画
- **Component Library:** `landing_*` に加え、ゲーム画面用「Resonance HUD」コンポーネント設計を追加予定。
- **Themes:** 夜（Midnight）に加え「黎明（Dawn）」バリアントを検討。
- **Guideline Enforcement:** 開発タスク時は PR/MR 説明に「TRDS 準拠」チェック項目を入れる。

---

このドキュメントを参照し、全 UI 実装者（含: AIエージェント）は TRDS の命名・トークン・構造を使用してください。必要に応じて追記/更新を行い、`.cursorrules` または各アプリ README からリンクしてください。

