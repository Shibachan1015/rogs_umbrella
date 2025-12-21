defmodule Shinkanki.Repo.Migrations.RebalanceCardsAndSeedMigakiOkami do
  use Ecto.Migration

  def up do
    # ===========================================
    # 1. イベントカードのネガティブ効果を軽減
    # ===========================================

    # 森林火災: F-3 → F-2
    execute """
    UPDATE event_cards SET effect_forest = -2
    WHERE name = '森林火災'
    """

    # 豪雨災害: F-2 → F-1
    execute """
    UPDATE event_cards SET effect_forest = -1
    WHERE name = '豪雨災害'
    """

    # 外来種の侵入: F-2 → F-1
    execute """
    UPDATE event_cards SET effect_forest = -1
    WHERE name = '外来種の侵入'
    """

    # ===========================================
    # 2. アクションカードのポジティブ効果を強化
    # ===========================================

    # 鎮守の森 植樹祭: F+2 → F+3
    execute """
    UPDATE action_cards SET effect_forest = 3
    WHERE name = '鎮守の森 植樹祭'
    """

    # 里山整備: F+2 → F+3
    execute """
    UPDATE action_cards SET effect_forest = 3
    WHERE name = '里山整備'
    """

    # 水源の森保全: F+2 → F+3
    execute """
    UPDATE action_cards SET effect_forest = 3
    WHERE name = '水源の森保全'
    """

    # 野生動物との共存: F+2 → F+3
    execute """
    UPDATE action_cards SET effect_forest = 3
    WHERE name = '野生動物との共存'
    """

    # 森林学校: F+1 → F+2
    execute """
    UPDATE action_cards SET effect_forest = 2
    WHERE name = '森林学校'
    """

    # 古木の守り: F+1 → F+2
    execute """
    UPDATE action_cards SET effect_forest = 2
    WHERE name = '古木の守り'
    """

    # ===========================================
    # 3. 磨きカードをシード
    # ===========================================

    execute """
    INSERT INTO migaki_cards (id, name, category, description, tags, cost_akasha, effect_forest, effect_culture, effect_social, effect_jaki, special_effect, inserted_at, updated_at)
    VALUES
    (gen_random_uuid(), '手前味噌を仕込む', 'kitchen', '発酵食品づくりで森と文化を守る', ARRAY['発酵', '台所', 'てしごと'], 1, 1, 1, 0, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '野菜を育てて食卓にのせる', 'forest', '自家菜園から始まる森との暮らし', ARRAY['育てる', '食', '森'], 1, 2, 0, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '鎮守の森 手入れの日', 'forest', '地域で森を守る定期活動', ARRAY['森', 'コミュニティ', '浄化'], 2, 2, 0, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '井戸端会議', 'care', '何気ない会話が絆を紡ぐ', ARRAY['対話', 'ケア', '絆'], 0, 0, 0, 2, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), 'お裾分けの輪', 'care', '余りものを分け合う文化', ARRAY['分かち合い', 'ケア', '食'], 0, 0, 1, 2, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '縁側でお茶', 'care', 'ゆっくり過ごす時間が心を癒す', ARRAY['休息', 'ケア', '対話'], 0, 0, 1, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '小さな祭りの準備', 'festival', '地域の祭りを守り続ける', ARRAY['祭り', '文化', 'コミュニティ'], 2, 0, 2, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '夏祭りの盆踊り', 'festival', '踊りを通じて世代をつなぐ', ARRAY['祭り', '踊り', '絆'], 1, 0, 2, 2, -2, NULL, NOW(), NOW()),
    (gen_random_uuid(), '神棚のお掃除', 'kitchen', '日々の感謝を形にする', ARRAY['浄化', '祈り', 'てしごと'], 0, 0, 1, 0, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '焚き火を囲む', 'forest', '火を囲んで語り合う原点回帰', ARRAY['火', '対話', '森'], 1, 1, 1, 2, -2, NULL, NOW(), NOW()),
    (gen_random_uuid(), '川の清掃', 'forest', '水辺を守る地域活動', ARRAY['水', '浄化', 'コミュニティ'], 1, 2, 0, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '竹林整備', 'forest', '放置竹林を資源に変える', ARRAY['森', 'てしごと', '循環'], 2, 3, 0, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '干し柿づくり', 'kitchen', '保存食文化の継承', ARRAY['食', '発酵', '継承'], 1, 1, 2, 0, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '草木染め体験', 'kitchen', '自然の色で染める伝統技術', ARRAY['てしごと', '文化', '森'], 1, 1, 2, 1, -1, NULL, NOW(), NOW()),
    (gen_random_uuid(), '大掃除の日', 'special', '年末の大掃除で邪気を祓う', ARRAY['浄化', '全体', '年中行事'], 3, 1, 1, 1, -3, '全パラメータ+1、邪気-3', NOW(), NOW())
    ON CONFLICT (name) DO NOTHING
    """

    # ===========================================
    # 4. 大神様カードを強化（既存カードの効果アップ）
    # ===========================================

    # 天照大御神の祝福を強化
    execute """
    UPDATE okami_cards SET effect_forest = 2, effect_culture = 2, effect_social = 2
    WHERE name LIKE '%天照%'
    """

    # 大国主命の恵みを強化
    execute """
    UPDATE okami_cards SET effect_forest = 2, effect_culture = 1, effect_social = 3
    WHERE name LIKE '%大国主%'
    """

    # 木花咲耶姫の祝福を強化
    execute """
    UPDATE okami_cards SET effect_forest = 3, effect_culture = 2, effect_social = 1
    WHERE name LIKE '%木花咲耶%'
    """

    # 追加の大神様カードをシード
    execute """
    INSERT INTO okami_cards (id, name, deity_name, description, effect_forest, effect_culture, effect_social, effect_akasha, special_effect, inserted_at, updated_at)
    VALUES
    (gen_random_uuid(), '月読命の静寂', '月読命', '月の神が夜の静けさをもたらし、心を癒す', 1, 2, 2, 0, '邪気-2', NOW(), NOW()),
    (gen_random_uuid(), '須佐之男命の勇気', '須佐之男命', '嵐の神が困難を打ち破る力を授ける', 2, 1, 2, 0, '次のネガティブイベントを無効化', NOW(), NOW()),
    (gen_random_uuid(), '稲荷大神の豊穣', '稲荷大神', '五穀豊穣の神が実りをもたらす', 3, 1, 1, 100, NULL, NOW(), NOW()),
    (gen_random_uuid(), '山神様の加護', '山神', '山の神が森を守護する', 4, 0, 1, 0, '森系カードの効果+1', NOW(), NOW()),
    (gen_random_uuid(), '水神様の恵み', '水神', '水の神が清らかな流れをもたらす', 2, 0, 2, 50, '水源の回復', NOW(), NOW())
    ON CONFLICT (name) DO NOTHING
    """
  end

  def down do
    # Rollback: Reset event cards to original values
    execute """
    UPDATE event_cards SET effect_forest = -3
    WHERE name = '森林火災'
    """

    execute """
    UPDATE event_cards SET effect_forest = -2
    WHERE name = '豪雨災害'
    """

    execute """
    UPDATE event_cards SET effect_forest = -2
    WHERE name = '外来種の侵入'
    """

    # Rollback: Reset action cards to original values
    execute """
    UPDATE action_cards SET effect_forest = 2
    WHERE name IN ('鎮守の森 植樹祭', '里山整備', '水源の森保全', '野生動物との共存')
    """

    execute """
    UPDATE action_cards SET effect_forest = 1
    WHERE name IN ('森林学校', '古木の守り')
    """

    # Remove seeded migaki cards
    execute """
    DELETE FROM migaki_cards
    WHERE name IN (
      '手前味噌を仕込む', '野菜を育てて食卓にのせる', '鎮守の森 手入れの日',
      '井戸端会議', 'お裾分けの輪', '縁側でお茶', '小さな祭りの準備',
      '夏祭りの盆踊り', '神棚のお掃除', '焚き火を囲む', '川の清掃',
      '竹林整備', '干し柿づくり', '草木染め体験', '大掃除の日'
    )
    """

    # Remove additional okami cards
    execute """
    DELETE FROM okami_cards
    WHERE name IN (
      '月読命の静寂', '須佐之男命の勇気', '稲荷大神の豊穣',
      '山神様の加護', '水神様の恵み'
    )
    """
  end
end
