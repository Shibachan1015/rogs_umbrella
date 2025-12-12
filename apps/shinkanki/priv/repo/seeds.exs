# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Shinkanki.Repo.insert!(%Shinkanki.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Shinkanki.Repo
alias Shinkanki.Games.{ActionCard, EventCard, ProjectTemplate, TalentCard}

# ===================
# アクションカード（28枚）
# ===================

# 森系（8枚）
forest_cards = [
  %{
    name: "鎮守の森 植樹祭",
    category: "forest",
    effect_forest: 2,
    effect_culture: -1,
    effect_social: 1,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の人々が集まり、鎮守の森に新しい木を植える。"
  },
  %{
    name: "山の神への奉仕",
    category: "forest",
    effect_forest: 1,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: -100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 100,
    description: "山の神に感謝を捧げ、森の恵みを祈る。"
  },
  %{
    name: "里山整備",
    category: "forest",
    effect_forest: 2,
    effect_culture: 0,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "放置された里山を整備し、生態系を回復させる。"
  },
  %{
    name: "水源の森保全",
    category: "forest",
    effect_forest: 2,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "水源となる森を守り、清らかな水を未来へつなぐ。"
  },
  %{
    name: "森の恵み収穫祭",
    category: "forest",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "森からの恵みに感謝し、収穫を祝う祭り。"
  },
  %{
    name: "野生動物との共存",
    category: "forest",
    effect_forest: 2,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: -1,
    cost_social: 0,
    cost_akasha: 0,
    description: "野生動物と人間が共存できる環境を整える。"
  },
  %{
    name: "森林学校",
    category: "forest",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 50,
    description: "子どもたちに森の大切さを教える学校を開く。"
  },
  %{
    name: "古木の守り",
    category: "forest",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 0,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の象徴である古木を守り続ける。"
  }
]

# 文化系（8枚）
culture_cards = [
  %{
    name: "鎮守の祭り準備",
    category: "culture",
    effect_forest: -1,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の鎮守の祭りの準備を行う。"
  },
  %{
    name: "職人技 継承の稽古日",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: -100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 100,
    description: "伝統の職人技を次世代に継承する稽古日。"
  },
  %{
    name: "伝統工芸展示会",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の伝統工芸を展示し、広く知ってもらう。"
  },
  %{
    name: "古文書の保存",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 0,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 50,
    description: "地域に伝わる古文書を保存・デジタル化する。"
  },
  %{
    name: "語り部の夜",
    category: "culture",
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 2,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "年配者から若者へ、地域の物語を語り継ぐ夜。"
  },
  %{
    name: "郷土料理教室",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の郷土料理を学び、継承する教室。"
  },
  %{
    name: "伝統音楽の継承",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域に伝わる音楽を次世代に伝える。"
  },
  %{
    name: "民話の記録",
    category: "culture",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 0,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域の民話を収集し、記録に残す。"
  }
]

# コミュニティ系（8枚）
social_cards = [
  %{
    name: "子ども食堂と見守り",
    category: "social",
    effect_forest: 0,
    effect_culture: -1,
    effect_social: 2,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "子どもたちに食事を提供し、地域で見守る。"
  },
  %{
    name: "村じゅうお掃除の日",
    category: "social",
    effect_forest: 1,
    effect_culture: 0,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域全体で一斉に清掃活動を行う。"
  },
  %{
    name: "多世代交流会",
    category: "social",
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 2,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "お年寄りから子どもまで、世代を超えた交流会。"
  },
  %{
    name: "助け合いネットワーク",
    category: "social",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 2,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "困ったときに助け合えるネットワークを構築。"
  },
  %{
    name: "空き家再生プロジェクト",
    category: "social",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 100,
    description: "空き家を改修し、新しい用途に活用する。"
  },
  %{
    name: "地域通貨の輪",
    category: "social",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 2,
    effect_akasha: 150,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域内で使える独自通貨を広める。"
  },
  %{
    name: "新住民歓迎会",
    category: "social",
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 2,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "地域に移住してきた人々を温かく迎える。"
  },
  %{
    name: "困りごと相談所",
    category: "social",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 2,
    effect_akasha: 50,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "住民の困りごとに寄り添い、解決を支援する。"
  }
]

# 空環系（4枚）
akasha_cards = [
  %{
    name: "空環アップグレード",
    category: "akasha",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 200,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "空環システムをアップグレードし、次ターン減衰無効。",
    special_effect: "next_turn_no_demurrage"
  },
  %{
    name: "緊急循環促進",
    category: "akasha",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "DAOプールから全員に+100配布。",
    special_effect: "distribute_from_dao_100"
  },
  %{
    name: "空環ネットワーク拡大",
    category: "akasha",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 1,
    effect_akasha: 100,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "空環ネットワークを拡大し、コミュニティを強化。"
  },
  %{
    name: "循環の儀式",
    category: "akasha",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 0,
    cost_forest: 0,
    cost_culture: 0,
    cost_social: 0,
    cost_akasha: 0,
    description: "空環を通じた循環の儀式で全てのパラメータを少し上げる。"
  }
]

# アクションカードを挿入
all_action_cards = forest_cards ++ culture_cards ++ social_cards ++ akasha_cards

Enum.each(all_action_cards, fn card_attrs ->
  %ActionCard{}
  |> ActionCard.changeset(card_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ #{length(all_action_cards)} アクションカードを挿入しました")

# ===================
# イベントカード（20枚）
# ===================

# ポジティブ（7枚）
positive_events = [
  %{
    name: "豊作の年",
    type: "positive",
    effect_forest: 1,
    effect_culture: 0,
    effect_social: 1,
    effect_akasha: 100,
    description: "今年は豊作！森も人々も潤う。",
    has_choice: false
  },
  %{
    name: "若者のUターン",
    type: "positive",
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 2,
    effect_akasha: 0,
    description: "都会から若者が戻ってきた。",
    has_choice: false
  },
  %{
    name: "天照大御神の祝福",
    type: "positive",
    effect_forest: 1,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 0,
    description: "天照大御神の祝福が地域に降り注ぐ。",
    has_choice: false
  },
  %{
    name: "伝統の復活",
    type: "positive",
    effect_forest: 0,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 0,
    description: "失われかけていた伝統が復活した。",
    has_choice: false
  },
  %{
    name: "観光客の訪問",
    type: "positive",
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 1,
    effect_akasha: 150,
    description: "多くの観光客が地域を訪れ、経済が潤う。",
    has_choice: false
  },
  %{
    name: "大国主命の恵み",
    type: "positive",
    effect_forest: 1,
    effect_culture: 0,
    effect_social: 2,
    effect_akasha: 0,
    description: "大国主命の恵みにより、縁が結ばれる。",
    has_choice: false
  },
  %{
    name: "木花咲耶姫の祝福",
    type: "positive",
    effect_forest: 2,
    effect_culture: 1,
    effect_social: 0,
    effect_akasha: 0,
    description: "木花咲耶姫の祝福で、花々が咲き誇る。",
    has_choice: false
  }
]

# ネガティブ（8枚）
negative_events = [
  %{
    name: "豪雨災害",
    type: "negative",
    effect_forest: -2,
    effect_culture: 0,
    effect_social: -1,
    effect_akasha: 0,
    description: "豪雨により森と地域に被害が出た。",
    has_choice: false
  },
  %{
    name: "伝統職人の引退",
    type: "negative",
    effect_forest: 0,
    effect_culture: -2,
    effect_social: -1,
    effect_akasha: 0,
    description: "最後の伝統職人が引退してしまった。",
    has_choice: false
  },
  %{
    name: "若者の流出",
    type: "negative",
    effect_forest: 0,
    effect_culture: -1,
    effect_social: -2,
    effect_akasha: 0,
    description: "若者が都会へ出て行ってしまった。",
    has_choice: false
  },
  %{
    name: "森林火災",
    type: "negative",
    effect_forest: -3,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "森林火災により、大きな被害が出た。",
    has_choice: false
  },
  %{
    name: "外来種の侵入",
    type: "negative",
    effect_forest: -2,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "外来種が侵入し、生態系が乱れた。",
    has_choice: false
  },
  %{
    name: "地域の対立",
    type: "negative",
    effect_forest: 0,
    effect_culture: -1,
    effect_social: -2,
    effect_akasha: 0,
    description: "地域内で対立が生まれてしまった。",
    has_choice: false
  },
  %{
    name: "経済不況",
    type: "negative",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: -1,
    effect_akasha: -100,
    description: "経済不況により、地域経済が冷え込む。",
    has_choice: false
  },
  %{
    name: "文化財の損傷",
    type: "negative",
    effect_forest: 0,
    effect_culture: -2,
    effect_social: 0,
    effect_akasha: 0,
    description: "大切な文化財が損傷してしまった。",
    has_choice: false
  }
]

# 選択肢あり（5枚）
choice_events = [
  %{
    name: "旧経済の誘惑",
    type: "choice",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "大企業から開発の提案が来た。",
    has_choice: true,
    choice_a_text: "受け入れる: S+3, Akasha+300 / F-2, K-2",
    choice_a_effects: %{"forest" => -2, "culture" => -2, "social" => 3, "akasha" => 300},
    choice_b_text: "断る: F+1, K+1 / S-1, Akasha-100",
    choice_b_effects: %{"forest" => 1, "culture" => 1, "social" => -1, "akasha" => -100}
  },
  %{
    name: "大規模開発の提案",
    type: "choice",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "大規模なリゾート開発の提案が来た。",
    has_choice: true,
    choice_a_text: "受け入れる: S+2, Akasha+400 / F-3, K-1",
    choice_a_effects: %{"forest" => -3, "culture" => -1, "social" => 2, "akasha" => 400},
    choice_b_text: "断る: F+1 / Akasha-50",
    choice_b_effects: %{"forest" => 1, "culture" => 0, "social" => 0, "akasha" => -50}
  },
  %{
    name: "伝統 vs 革新",
    type: "choice",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "伝統を守るか、革新を選ぶかの岐路に立つ。",
    has_choice: true,
    choice_a_text: "伝統重視: K+2 / S-1",
    choice_a_effects: %{"forest" => 0, "culture" => 2, "social" => -1, "akasha" => 0},
    choice_b_text: "革新重視: S+2 / K-1",
    choice_b_effects: %{"forest" => 0, "culture" => -1, "social" => 2, "akasha" => 0}
  },
  %{
    name: "観光開発",
    type: "choice",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "観光開発を積極的に進めるか、抑制するか。",
    has_choice: true,
    choice_a_text: "推進: S+2, Akasha+200 / F-1, K-1",
    choice_a_effects: %{"forest" => -1, "culture" => -1, "social" => 2, "akasha" => 200},
    choice_b_text: "抑制: F+1, K+1 / Akasha-100",
    choice_b_effects: %{"forest" => 1, "culture" => 1, "social" => 0, "akasha" => -100}
  },
  %{
    name: "AIの導入",
    type: "choice",
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 0,
    effect_akasha: 0,
    description: "地域にAIシステムを導入するかどうか。",
    has_choice: true,
    choice_a_text: "導入: Akasha+300, S+1 / K-1",
    choice_a_effects: %{"forest" => 0, "culture" => -1, "social" => 1, "akasha" => 300},
    choice_b_text: "見送り: K+1 / Akasha-50",
    choice_b_effects: %{"forest" => 0, "culture" => 1, "social" => 0, "akasha" => -50}
  }
]

# イベントカードを挿入
all_event_cards = positive_events ++ negative_events ++ choice_events

Enum.each(all_event_cards, fn event_attrs ->
  %EventCard{}
  |> EventCard.changeset(event_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ #{length(all_event_cards)} イベントカードを挿入しました")

# ===================
# プロジェクトテンプレート（5つ）
# ===================

project_templates = [
  %{
    name: "地域まるごと文化祭",
    description: "地域全体を使った大規模な文化祭を開催する。",
    required_participants: 4,
    required_turns: nil,
    required_dao_pool: nil,
    effect_forest: 0,
    effect_culture: 3,
    effect_social: 3,
    effect_akasha: 200,
    permanent_effect: nil,
    permanent_effect_value: nil
  },
  %{
    name: "多世代シェア工房",
    description: "世代を超えて技術を共有する工房を作る。",
    required_participants: 5,
    required_turns: 3,
    required_dao_pool: nil,
    effect_forest: 1,
    effect_culture: 2,
    effect_social: 2,
    effect_akasha: 0,
    permanent_effect: "repair_bonus",
    permanent_effect_value: 1
  },
  %{
    name: "森と暮らしの学校",
    description: "森と共に暮らすことを学ぶ学校を開設。",
    required_participants: 4,
    required_turns: nil,
    required_dao_pool: nil,
    effect_forest: 2,
    effect_culture: 2,
    effect_social: 1,
    effect_akasha: 0,
    permanent_effect: "planting_bonus",
    permanent_effect_value: 1
  },
  %{
    name: "空環マーケット",
    description: "空環を使った地域マーケットを開催。",
    required_participants: 4,
    required_turns: nil,
    required_dao_pool: 500,
    effect_forest: 0,
    effect_culture: 0,
    effect_social: 2,
    effect_akasha: 300,
    permanent_effect: "demurrage_reduction",
    permanent_effect_value: 5
  },
  %{
    name: "夜の語り部の会",
    description: "地域の物語を語り継ぐ夜の集まり。",
    required_participants: 3,
    required_turns: nil,
    required_dao_pool: nil,
    effect_forest: 0,
    effect_culture: 1,
    effect_social: 3,
    effect_akasha: 0,
    permanent_effect: "conflict_reduction",
    permanent_effect_value: 1
  }
]

Enum.each(project_templates, fn template_attrs ->
  %ProjectTemplate{}
  |> ProjectTemplate.changeset(template_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ #{length(project_templates)} プロジェクトテンプレートを挿入しました")

# ===================
# タレントカード（16枚 - 各役割4枚）
# ===================

# 森の守護者（Forest Guardian）のタレント
forest_guardian_talents = [
  %{
    name: "森の知恵",
    category: "forest",
    description: "森への深い理解。Forest系カードの効果+1",
    compatible_tags: ["forest"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "自然との対話",
    category: "forest",
    description: "自然の声を聞き、調和をもたらす力",
    compatible_tags: ["forest", "social"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "木霊の導き",
    category: "forest",
    description: "木霊に導かれ、森の秘密を知る",
    compatible_tags: ["forest"],
    effect_type: "cost_reduction",
    effect_value: 50
  },
  %{
    name: "森林再生の術",
    category: "forest",
    description: "傷ついた森を癒す特別な力",
    compatible_tags: ["forest"],
    effect_type: "bonus",
    effect_value: 2
  }
]

# 伝承の紡ぎ手（Heritage Weaver）のタレント
heritage_weaver_talents = [
  %{
    name: "伝承の継承",
    category: "culture",
    description: "文化への深い理解。Culture系カードの効果+1",
    compatible_tags: ["culture"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "物語の紡ぎ手",
    category: "culture",
    description: "物語を通じて人々の心をつなぐ力",
    compatible_tags: ["culture", "social"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "古の記憶",
    category: "culture",
    description: "過去の知恵を呼び覚ます力",
    compatible_tags: ["culture"],
    effect_type: "cost_reduction",
    effect_value: 50
  },
  %{
    name: "職人の魂",
    category: "culture",
    description: "伝統技術を極める職人の魂",
    compatible_tags: ["culture"],
    effect_type: "bonus",
    effect_value: 2
  }
]

# 共同体の守り手（Community Keeper）のタレント
community_keeper_talents = [
  %{
    name: "絆の守り手",
    category: "social",
    description: "社会への深い理解。Social系カードの効果+1",
    compatible_tags: ["social"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "調停者",
    category: "social",
    description: "対立を解消し、協力を促進する力",
    compatible_tags: ["social", "culture"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "共感の波動",
    category: "social",
    description: "人々の心に寄り添い、理解する力",
    compatible_tags: ["social"],
    effect_type: "cost_reduction",
    effect_value: 50
  },
  %{
    name: "コミュニティの絆",
    category: "social",
    description: "地域の絆を強化する特別な力",
    compatible_tags: ["social"],
    effect_type: "bonus",
    effect_value: 2
  }
]

# 空環の設計者（Akasha Architect）のタレント
akasha_architect_talents = [
  %{
    name: "空環の設計者",
    category: "akasha",
    description: "Akashaの流れを読み、効率的に運用する力",
    compatible_tags: ["akasha"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "循環の知恵",
    category: "akasha",
    description: "リソースの循環を最適化する力",
    compatible_tags: ["akasha", "forest"],
    effect_type: "bonus",
    effect_value: 1
  },
  %{
    name: "減衰の制御",
    category: "akasha",
    description: "Akashaの減衰を抑える技術",
    compatible_tags: ["akasha"],
    effect_type: "cost_reduction",
    effect_value: 100
  },
  %{
    name: "DAOの導き",
    category: "akasha",
    description: "DAOプールとの深いつながり",
    compatible_tags: ["akasha"],
    effect_type: "bonus",
    effect_value: 2
  }
]

# タレントカードを挿入
all_talent_cards =
  forest_guardian_talents ++
    heritage_weaver_talents ++ community_keeper_talents ++ akasha_architect_talents

Enum.each(all_talent_cards, fn talent_attrs ->
  %TalentCard{}
  |> TalentCard.changeset(talent_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ #{length(all_talent_cards)} タレントカードを挿入しました")

IO.puts("")
IO.puts("🎉 シードデータの挿入が完了しました！")
IO.puts("   - アクションカード: #{length(all_action_cards)}枚")
IO.puts("   - イベントカード: #{length(all_event_cards)}枚")
IO.puts("   - プロジェクトテンプレート: #{length(project_templates)}個")
IO.puts("   - タレントカード: #{length(all_talent_cards)}枚")
