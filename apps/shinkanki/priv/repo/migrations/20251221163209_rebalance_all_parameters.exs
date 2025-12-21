defmodule Shinkanki.Repo.Migrations.RebalanceAllParameters do
  use Ecto.Migration

  def up do
    # ===========================================
    # 1. ネガティブイベントの全パラメータを軽減
    # ===========================================

    # 文化系ネガティブを軽減
    # 伝統職人の引退: K-2 → K-1
    execute """
    UPDATE event_cards SET effect_culture = -1
    WHERE name = '伝統職人の引退'
    """

    # 文化財の損傷: K-2 → K-1
    execute """
    UPDATE event_cards SET effect_culture = -1
    WHERE name = '文化財の損傷'
    """

    # コミュニティ系ネガティブを軽減
    # 若者の流出: S-2 → S-1
    execute """
    UPDATE event_cards SET effect_social = -1
    WHERE name = '若者の流出'
    """

    # 地域の対立: S-2 → S-1
    execute """
    UPDATE event_cards SET effect_social = -1
    WHERE name = '地域の対立'
    """

    # ===========================================
    # 2. アクションカードのクロスカテゴリ効果を強化
    # ===========================================

    # 森系カードに文化・コミュニティ効果を追加
    # 里山整備: F+3(強化済), K0→K+1, S+1維持
    execute """
    UPDATE action_cards SET effect_culture = 1
    WHERE name = '里山整備'
    """

    # 水源の森保全: F+3(強化済), K0→K+1, S0→S+1
    execute """
    UPDATE action_cards SET effect_culture = 1, effect_social = 1
    WHERE name = '水源の森保全'
    """

    # 野生動物との共存: F+3(強化済), K0→K+1, S0→S+1
    execute """
    UPDATE action_cards SET effect_culture = 1, effect_social = 1
    WHERE name = '野生動物との共存'
    """

    # 文化系カードに森・コミュニティ効果を追加
    # 鎮守の祭り準備: F-1→F+1, K+2維持, S+1維持
    execute """
    UPDATE action_cards SET effect_forest = 1
    WHERE name = '鎮守の祭り準備'
    """

    # 古文書の保存: F0→F+1, K+2維持, S0→S+1
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_social = 1
    WHERE name = '古文書の保存'
    """

    # 民話の記録: F0→F+1, K+2維持, S0→S+1
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_social = 1
    WHERE name = '民話の記録'
    """

    # コミュニティ系カードに森・文化効果を追加
    # 子ども食堂と見守り: F0→F+1, K-1→K+1, S+2維持
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_culture = 1
    WHERE name = '子ども食堂と見守り'
    """

    # 助け合いネットワーク: F0→F+1, K0→K+1, S+2維持
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_culture = 1
    WHERE name = '助け合いネットワーク'
    """

    # 地域通貨の輪: F0→F+1, K0→K+1, S+2維持
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_culture = 1
    WHERE name = '地域通貨の輪'
    """

    # 困りごと相談所: F0→F+1, K0→K+1, S+2維持
    execute """
    UPDATE action_cards SET effect_forest = 1, effect_culture = 1
    WHERE name = '困りごと相談所'
    """

    # ===========================================
    # 3. ポジティブイベントを強化
    # ===========================================

    # 豊作の年: F+1→F+2, K0→K+1, S+1→S+2
    execute """
    UPDATE event_cards SET effect_forest = 2, effect_culture = 1, effect_social = 2
    WHERE name = '豊作の年'
    """

    # 若者のUターン: F0→F+1, K+1→K+2, S+2→S+3
    execute """
    UPDATE event_cards SET effect_forest = 1, effect_culture = 2, effect_social = 3
    WHERE name = '若者のUターン'
    """

    # 伝統の復活: F0→F+1, K+2→K+3, S+1→S+2
    execute """
    UPDATE event_cards SET effect_forest = 1, effect_culture = 3, effect_social = 2
    WHERE name = '伝統の復活'
    """

    # 観光客の訪問: F0→F+1, K+1→K+2, S+1→S+2
    execute """
    UPDATE event_cards SET effect_forest = 1, effect_culture = 2, effect_social = 2
    WHERE name = '観光客の訪問'
    """

    # ===========================================
    # 4. 磨きカードの全パラメータ強化
    # ===========================================

    # 竹林整備: F+3維持, K0→K+1, S+1維持
    execute """
    UPDATE migaki_cards SET effect_culture = 1
    WHERE name = '竹林整備'
    """

    # 川の清掃: F+2維持, K0→K+1, S+1維持
    execute """
    UPDATE migaki_cards SET effect_culture = 1
    WHERE name = '川の清掃'
    """

    # 野菜を育てて食卓にのせる: F+2維持, K0→K+1, S+1維持
    execute """
    UPDATE migaki_cards SET effect_culture = 1
    WHERE name = '野菜を育てて食卓にのせる'
    """

    # 鎮守の森 手入れの日: F+2維持, K0→K+1, S+1維持
    execute """
    UPDATE migaki_cards SET effect_culture = 1
    WHERE name = '鎮守の森 手入れの日'
    """

    # 井戸端会議: F0→F+1, K0→K+1, S+2維持
    execute """
    UPDATE migaki_cards SET effect_forest = 1, effect_culture = 1
    WHERE name = '井戸端会議'
    """

    # お裾分けの輪: F0→F+1, K+1維持, S+2維持
    execute """
    UPDATE migaki_cards SET effect_forest = 1
    WHERE name = 'お裾分けの輪'
    """

    # 縁側でお茶: F0→F+1, K+1維持, S+1→S+2
    execute """
    UPDATE migaki_cards SET effect_forest = 1, effect_social = 2
    WHERE name = '縁側でお茶'
    """

    # ===========================================
    # 5. 大神様カードのバランス調整
    # ===========================================

    # 月読命の静寂: F+1→F+2
    execute """
    UPDATE okami_cards SET effect_forest = 2
    WHERE name = '月読命の静寂'
    """

    # 稲荷大神の豊穣: F+3維持, K+1→K+2, S+1→S+2
    execute """
    UPDATE okami_cards SET effect_culture = 2, effect_social = 2
    WHERE name = '稲荷大神の豊穣'
    """

    # 水神様の恵み: F+2維持, K0→K+1, S+2維持
    execute """
    UPDATE okami_cards SET effect_culture = 1
    WHERE name = '水神様の恵み'
    """
  end

  def down do
    # ネガティブイベントを元に戻す
    execute "UPDATE event_cards SET effect_culture = -2 WHERE name = '伝統職人の引退'"
    execute "UPDATE event_cards SET effect_culture = -2 WHERE name = '文化財の損傷'"
    execute "UPDATE event_cards SET effect_social = -2 WHERE name = '若者の流出'"
    execute "UPDATE event_cards SET effect_social = -2 WHERE name = '地域の対立'"

    # アクションカードを元に戻す
    execute "UPDATE action_cards SET effect_culture = 0 WHERE name = '里山整備'"
    execute "UPDATE action_cards SET effect_culture = 0, effect_social = 0 WHERE name = '水源の森保全'"
    execute "UPDATE action_cards SET effect_culture = 0, effect_social = 0 WHERE name = '野生動物との共存'"
    execute "UPDATE action_cards SET effect_forest = -1 WHERE name = '鎮守の祭り準備'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_social = 0 WHERE name = '古文書の保存'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_social = 0 WHERE name = '民話の記録'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_culture = -1 WHERE name = '子ども食堂と見守り'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_culture = 0 WHERE name = '助け合いネットワーク'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_culture = 0 WHERE name = '地域通貨の輪'"
    execute "UPDATE action_cards SET effect_forest = 0, effect_culture = 0 WHERE name = '困りごと相談所'"

    # ポジティブイベントを元に戻す
    execute "UPDATE event_cards SET effect_forest = 1, effect_culture = 0, effect_social = 1 WHERE name = '豊作の年'"
    execute "UPDATE event_cards SET effect_forest = 0, effect_culture = 1, effect_social = 2 WHERE name = '若者のUターン'"
    execute "UPDATE event_cards SET effect_forest = 0, effect_culture = 2, effect_social = 1 WHERE name = '伝統の復活'"
    execute "UPDATE event_cards SET effect_forest = 0, effect_culture = 1, effect_social = 1 WHERE name = '観光客の訪問'"

    # 磨きカードを元に戻す
    execute "UPDATE migaki_cards SET effect_culture = 0 WHERE name = '竹林整備'"
    execute "UPDATE migaki_cards SET effect_culture = 0 WHERE name = '川の清掃'"
    execute "UPDATE migaki_cards SET effect_culture = 0 WHERE name = '野菜を育てて食卓にのせる'"
    execute "UPDATE migaki_cards SET effect_culture = 0 WHERE name = '鎮守の森 手入れの日'"
    execute "UPDATE migaki_cards SET effect_forest = 0, effect_culture = 0 WHERE name = '井戸端会議'"
    execute "UPDATE migaki_cards SET effect_forest = 0 WHERE name = 'お裾分けの輪'"
    execute "UPDATE migaki_cards SET effect_forest = 0, effect_social = 1 WHERE name = '縁側でお茶'"

    # 大神様カードを元に戻す
    execute "UPDATE okami_cards SET effect_forest = 1 WHERE name = '月読命の静寂'"
    execute "UPDATE okami_cards SET effect_culture = 1, effect_social = 1 WHERE name = '稲荷大神の豊穣'"
    execute "UPDATE okami_cards SET effect_culture = 0 WHERE name = '水神様の恵み'"
  end
end
