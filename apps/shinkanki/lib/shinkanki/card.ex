defmodule Shinkanki.Card do
  @moduledoc """
  Defines card structures for Action Cards and Talent Cards in Shinkanki.
  """

  @type card_type :: :action | :talent | :project | :event | :hitoyo | :migaki

  @type t :: %__MODULE__{
          id: atom(),
          type: card_type(),
          name: String.t(),
          description: String.t(),
          # For action cards (P)
          cost: integer(),
          # Base effect for action cards
          effect: map(),
          # Tags for compatibility (e.g., :nature, :craft, :community)
          tags: list(atom()),
          # For talent cards: tags they boost
          compatible_tags: list(atom()),
          # For project cards: unlock condition
          unlock_condition: map(),
          # For project cards: required progress (number of talents needed)
          required_progress: integer(),
          # For hitoyo cards: timing type (:instant or :delayed)
          timing: atom(),
          # For hitoyo/migaki cards: category
          category: atom(),
          # For hitoyo cards: flavor text
          flavor: String.t(),
          # For hitoyo cards: condition for delayed effects
          condition: String.t(),
          # For migaki cards: special effect description
          special: String.t()
        }

  defstruct [
    :id,
    :type,
    :name,
    :description,
    :cost,
    :timing,
    :category,
    :flavor,
    :condition,
    :special,
    effect: %{},
    tags: [],
    compatible_tags: [],
    unlock_condition: %{},
    required_progress: 0
  ]

  @doc """
  Returns the list of all available cards (Actions, Talents, Projects, Events, Hitoyo, Migaki).
  """
  def list_cards do
    list_actions() ++
      list_talents() ++ list_projects() ++ list_events() ++ list_hitoyo() ++ list_migaki()
  end

  @doc """
  Returns only action cards.
  """
  def list_actions, do: actions()

  @doc """
  Returns only talent cards.
  """
  def list_talents, do: talents()

  @doc """
  Returns only project cards.
  """
  def list_projects, do: projects()

  @doc """
  Returns only event cards.
  """
  def list_events, do: events()

  @doc """
  Returns only hitoyo (人代) cards.
  """
  def list_hitoyo, do: hitoyo_cards()

  @doc """
  Returns only migaki (磨き) cards.
  """
  def list_migaki, do: migaki_cards()

  @doc """
  Gets an event card by ID.
  """
  def get_event(id) do
    case get_card(id) do
      %__MODULE__{type: :event} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets a card by its ID.
  """
  def get_card(id) do
    Enum.find(list_cards(), &(&1.id == id))
  end

  @doc """
  Gets an action card by ID.
  """
  def get_action(id) do
    case get_card(id) do
      %__MODULE__{type: :action} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets a talent card by ID.
  """
  def get_talent(id) do
    case get_card(id) do
      %__MODULE__{type: :talent} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets a project card by ID.
  """
  def get_project(id) do
    case get_card(id) do
      %__MODULE__{type: :project} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets a hitoyo (人代) card by ID.
  """
  def get_hitoyo(id) do
    case get_card(id) do
      %__MODULE__{type: :hitoyo} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets a migaki (磨き) card by ID.
  """
  def get_migaki(id) do
    case get_card(id) do
      %__MODULE__{type: :migaki} = card -> card
      _ -> nil
    end
  end

  @doc """
  Gets the number of hitoyo cards to draw based on jaki (邪気) level.
  jaki 0-2: 1 card, jaki 3-5: 2 cards, jaki 6-8: 3 cards
  """
  def hitoyo_count_for_jaki(jaki) when jaki >= 0 and jaki <= 2, do: 1
  def hitoyo_count_for_jaki(jaki) when jaki >= 3 and jaki <= 5, do: 2
  def hitoyo_count_for_jaki(jaki) when jaki >= 6 and jaki <= 8, do: 3
  def hitoyo_count_for_jaki(_), do: 1

  @doc """
  Draws random hitoyo cards based on jaki level.
  """
  def draw_hitoyo_cards(jaki_level) do
    count = hitoyo_count_for_jaki(jaki_level)

    hitoyo_cards()
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  @doc """
  Gets all migaki cards that can counter a specific hitoyo card.
  """
  def get_counter_migaki_for_hitoyo(%__MODULE__{id: hitoyo_id}) do
    migaki_cards()
    |> Enum.filter(fn migaki ->
      migaki.special && String.contains?(migaki.special, Atom.to_string(hitoyo_id))
    end)
  end

  # --- Action Cards (行動カード/営みカード) ---
  # Scale: 0-10 for F/K/S, costs in 空環 points (1-3)
  defp actions do
    [
      # Forest / Nature related
      %__MODULE__{
        id: :shokurin,
        type: :action,
        name: "植林 (Reforestation)",
        description: "Plant trees to restore nature.",
        cost: 1,
        effect: %{forest: 1},
        tags: [:nature, :grow]
      },
      # Culture / Event related
      %__MODULE__{
        id: :saiji,
        type: :action,
        name: "祭事 (Festival)",
        description: "Celebrate to boost culture.",
        cost: 2,
        effect: %{culture: 1, social: 1},
        tags: [:event, :culture]
      },
      # Social / Community related
      %__MODULE__{
        id: :houshi,
        type: :action,
        name: "奉仕 (Service)",
        description: "Community service strengthens bonds.",
        cost: 0,
        effect: %{social: 1},
        tags: [:community, :care]
      },
      # Economic / Trade
      %__MODULE__{
        id: :koueki,
        type: :action,
        name: "交易 (Trade)",
        description: "Trade brings wealth.",
        cost: 1,
        effect: %{currency: 2},
        tags: [:biz, :logistics]
      },
      # Making / Craft
      %__MODULE__{
        id: :seisaku,
        type: :action,
        name: "制作 (Crafting)",
        description: "Make tools or art.",
        cost: 1,
        effect: %{culture: 1},
        tags: [:craft, :make]
      },
      # Repair
      %__MODULE__{
        id: :shuri,
        type: :action,
        name: "修理 (Repair)",
        description: "Fix broken things.",
        cost: 1,
        effect: %{social: 1, forest: 1},
        tags: [:fix, :craft]
      }
    ]
  end

  # --- Talent Cards (才能カード) ---
  # Based on the website content
  defp talents do
    [
      %__MODULE__{
        id: :t_craft,
        type: :talent,
        name: "手しごとの才能 (Craft)",
        description: "Good at making things.",
        compatible_tags: [:craft, :make, :fix]
      },
      %__MODULE__{
        id: :t_plan,
        type: :talent,
        name: "企画の才能 (Planning)",
        description: "Good at planning events.",
        compatible_tags: [:event, :new]
      },
      %__MODULE__{
        id: :t_listen,
        type: :talent,
        name: "聴く才能 (Listening)",
        description: "Good at listening and care.",
        compatible_tags: [:community, :care, :dialogue]
      },
      %__MODULE__{
        id: :t_system,
        type: :talent,
        name: "仕組み化の才能 (System)",
        description: "Good at organizing systems.",
        compatible_tags: [:manage, :system]
      },
      %__MODULE__{
        id: :t_grow,
        type: :talent,
        name: "育てる才能 (Nurture)",
        description: "Good at growing plants and people.",
        compatible_tags: [:nature, :grow, :edu]
      },
      %__MODULE__{
        id: :t_express,
        type: :talent,
        name: "表現の才能 (Expression)",
        description: "Good at design and art.",
        compatible_tags: [:pr, :design, :culture]
      },
      %__MODULE__{
        id: :t_teach,
        type: :talent,
        name: "教える才能 (Teaching)",
        description: "Good at teaching.",
        compatible_tags: [:edu, :workshop]
      },
      %__MODULE__{
        id: :t_connect,
        type: :talent,
        name: "つなぐ才能 (Connecting)",
        description: "Good at connecting people.",
        compatible_tags: [:match, :intro]
      },
      %__MODULE__{
        id: :t_fix,
        type: :talent,
        name: "直す才能 (Fixing)",
        description: "Good at repairing.",
        compatible_tags: [:fix, :recycle]
      },
      %__MODULE__{
        id: :t_pr,
        type: :talent,
        name: "伝える才能 (PR)",
        description: "Good at communication.",
        compatible_tags: [:pr, :announce]
      },
      %__MODULE__{
        id: :t_viz,
        type: :talent,
        name: "見える化の才能 (Viz)",
        description: "Good at analysis.",
        compatible_tags: [:analyze, :plan]
      },
      %__MODULE__{
        id: :t_place,
        type: :talent,
        name: "場づくりの才能 (Place)",
        description: "Good at hosting.",
        compatible_tags: [:event, :community]
      },
      %__MODULE__{
        id: :t_detail,
        type: :talent,
        name: "細やかさの才能 (Detail)",
        description: "Good at details.",
        compatible_tags: [:quality, :finish]
      },
      %__MODULE__{
        id: :t_drive,
        type: :talent,
        name: "推進の才能 (Drive)",
        description: "Good at execution.",
        compatible_tags: [:exec, :start]
      },
      %__MODULE__{
        id: :t_mediator,
        type: :talent,
        name: "調停の才能 (Mediator)",
        description: "Good at resolving conflict.",
        compatible_tags: [:meeting, :conflict]
      },
      %__MODULE__{
        id: :t_vision,
        type: :talent,
        name: "ビジョンの才能 (Vision)",
        description: "Good at future planning.",
        compatible_tags: [:long_term, :policy]
      },
      %__MODULE__{
        id: :t_logistics,
        type: :talent,
        name: "物流の才能 (Logistics)",
        description: "Good at managing goods.",
        compatible_tags: [:logistics, :inventory]
      },
      %__MODULE__{
        id: :t_hospitality,
        type: :talent,
        name: "もてなしの才能 (Hospitality)",
        description: "Good at hospitality.",
        compatible_tags: [:event, :exchange]
      },
      %__MODULE__{
        id: :t_guard,
        type: :talent,
        name: "守りの才能 (Guard)",
        description: "Good at risk management.",
        compatible_tags: [:safety, :contract]
      },
      %__MODULE__{
        id: :t_learn,
        type: :talent,
        name: "学びの才能 (Learn)",
        description: "Good at learning new things.",
        compatible_tags: [:research, :try]
      }
    ]
  end

  # --- Project Cards (共創プロジェクト) ---
  # Scale: 0-10 for F/K/S, unlock conditions in 0-10 scale
  defp projects do
    [
      %__MODULE__{
        id: :p_forest_fest,
        type: :project,
        name: "森の祝祭 (Forest Festival)",
        description: "A grand festival in the forest. Requires 4 talents to complete.",
        cost: 5,
        effect: %{forest: 2, culture: 2, social: 2},
        tags: [:event, :nature, :community],
        unlock_condition: %{forest: 8, culture: 6},
        required_progress: 4
      },
      %__MODULE__{
        id: :p_market,
        type: :project,
        name: "定期市 (Regular Market)",
        description: "Establish a regular market system. Requires 3 talents to complete.",
        cost: 3,
        effect: %{currency: 5, social: 1},
        tags: [:biz, :system],
        unlock_condition: %{social: 7},
        required_progress: 3
      }
    ]
  end

  # --- Event Cards (イベントカード) ---
  # Scale: 0-10 for F/K/S, effects scaled appropriately
  # These are now legacy events - hitoyo cards are the main event system
  defp events do
    [
      # === 災害系 (Disasters) - 8 cards ===
      %__MODULE__{
        id: :e_drought,
        type: :event,
        name: "大干ばつ (Great Drought)",
        description: "長い干ばつが森を枯らす。",
        effect: %{forest: -2, jaki: 1},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_flood,
        type: :event,
        name: "大洪水 (Great Flood)",
        description: "洪水が文化遺産を破壊する。",
        effect: %{culture: -1, forest: -1},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_pestilence,
        type: :event,
        name: "疫病 (Pestilence)",
        description: "疫病がコミュニティを分断する。",
        effect: %{social: -2, jaki: 1},
        tags: [:disaster, :community]
      },
      %__MODULE__{
        id: :e_wildfire,
        type: :event,
        name: "山火事 (Wildfire)",
        description: "山火事が森を焼き尽くす。",
        effect: %{forest: -2, jaki: 1},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_cultural_loss,
        type: :event,
        name: "文化の喪失 (Cultural Loss)",
        description: "伝統が失われていく。",
        effect: %{culture: -2},
        tags: [:disaster, :culture]
      },
      %__MODULE__{
        id: :e_conflict,
        type: :event,
        name: "対立 (Conflict)",
        description: "コミュニティ内で対立が起きる。",
        effect: %{social: -2, jaki: 1},
        tags: [:disaster, :community]
      },
      %__MODULE__{
        id: :e_erosion,
        type: :event,
        name: "土壌流失 (Soil Erosion)",
        description: "土壌が失われ、森が弱る。",
        effect: %{forest: -1, culture: -1},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_isolation,
        type: :event,
        name: "孤立 (Isolation)",
        description: "人々が孤立し、つながりが薄れる。",
        effect: %{social: -1, jaki: 1},
        tags: [:disaster, :community]
      },

      # === 祭り・祝福系 (Festivals & Blessings) - 10 cards ===
      %__MODULE__{
        id: :e_harvest_festival,
        type: :event,
        name: "収穫祭 (Harvest Festival)",
        description: "豊作を祝う祭りが開かれる。",
        effect: %{forest: 1, culture: 1, social: 1},
        tags: [:festival, :nature]
      },
      %__MODULE__{
        id: :e_cultural_festival,
        type: :event,
        name: "文化祭 (Cultural Festival)",
        description: "文化を祝う祭りが開かれる。",
        effect: %{culture: 2, social: 1},
        tags: [:festival, :culture]
      },
      %__MODULE__{
        id: :e_community_gathering,
        type: :event,
        name: "コミュニティの集い (Community Gathering)",
        description: "人々が集まり、絆を深める。",
        effect: %{social: 2, culture: 1},
        tags: [:festival, :community]
      },
      %__MODULE__{
        id: :e_divine_blessing,
        type: :event,
        name: "神々の加護 (Divine Blessing)",
        description: "神々が世界に祝福を与える。",
        effect: %{forest: 1, culture: 1, social: 1, jaki: -1},
        tags: [:blessing, :divine]
      },
      %__MODULE__{
        id: :e_rain,
        type: :event,
        name: "恵みの雨 (Blessing Rain)",
        description: "恵みの雨が森を潤す。",
        effect: %{forest: 2},
        tags: [:blessing, :nature]
      },
      %__MODULE__{
        id: :e_artistic_awakening,
        type: :event,
        name: "芸術の目覚め (Artistic Awakening)",
        description: "新しい芸術が生まれる。",
        effect: %{culture: 2},
        tags: [:blessing, :culture]
      },
      %__MODULE__{
        id: :e_unity,
        type: :event,
        name: "結束 (Unity)",
        description: "人々が結束し、力を合わせる。",
        effect: %{social: 2, jaki: -1},
        tags: [:blessing, :community]
      },
      %__MODULE__{
        id: :e_nature_recovery,
        type: :event,
        name: "自然の回復 (Nature Recovery)",
        description: "自然が回復し始める。",
        effect: %{forest: 1, culture: 1},
        tags: [:blessing, :nature]
      },
      %__MODULE__{
        id: :e_tradition_revival,
        type: :event,
        name: "伝統の復興 (Tradition Revival)",
        description: "古い伝統が再び息づく。",
        effect: %{culture: 1, social: 1},
        tags: [:blessing, :culture]
      },
      %__MODULE__{
        id: :e_mutual_aid,
        type: :event,
        name: "相互扶助 (Mutual Aid)",
        description: "人々が互いに助け合う。",
        effect: %{social: 1, forest: 1},
        tags: [:blessing, :community]
      },

      # === 旧経済の誘惑 (Old Economy Temptations) - 4 cards ===
      %__MODULE__{
        id: :e_quick_profit,
        type: :event,
        name: "急な利益 (Quick Profit)",
        description: "短期的な利益がもたらされるが、代償がある。",
        effect: %{currency: 3, forest: -1, jaki: 1},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_industrial_boom,
        type: :event,
        name: "産業ブーム (Industrial Boom)",
        description: "産業が発展するが、環境に負担がかかる。",
        effect: %{currency: 2, forest: -1, jaki: 1},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_speculation,
        type: :event,
        name: "投機 (Speculation)",
        description: "投機で一時的な富が生まれるが、不安定さが増す。",
        effect: %{currency: 2, social: -1, jaki: 1},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_short_term_gain,
        type: :event,
        name: "短期的な利益 (Short-term Gain)",
        description: "短期的な利益がもたらされるが、長期的な損失がある。",
        effect: %{currency: 2, jaki: 1},
        tags: [:temptation, :economy]
      },

      # === 特殊イベント (Special Events) - 3 cards ===
      %__MODULE__{
        id: :e_balance,
        type: :event,
        name: "調和 (Balance)",
        description: "すべてが調和し、バランスが取れる。",
        effect: %{forest: 1, culture: 1, social: 1, jaki: -1},
        tags: [:special, :balance]
      },
      %__MODULE__{
        id: :e_windfall,
        type: :event,
        name: "予期せぬ収入 (Windfall)",
        description: "予期せぬ収入が入る。",
        effect: %{currency: 2},
        tags: [:special, :economy]
      },
      %__MODULE__{
        id: :e_wisdom,
        type: :event,
        name: "知恵の光 (Light of Wisdom)",
        description: "古い知恵が新たな光を放つ。",
        effect: %{culture: 1, social: 1},
        tags: [:special, :wisdom]
      }
    ]
  end

  # --- 人代（ひとよ）カード ---
  # 現代社会の流れ（環境破壊・物理的誘惑・文化の切り捨て・分断など）を表すカード
  # effect: 即時効果（F/K/S/邪気への影響）
  defp hitoyo_cards do
    [
      # === 環境破壊系 ===
      %__MODULE__{
        id: :h_mega_project,
        type: :hitoyo,
        name: "山肌むき出しメガプロジェクト",
        description: "開発という名の暴力が、山を削り取る。",
        flavor: "効率と利益のために、自然が犠牲になる。",
        timing: :instant,
        category: :env_destruction,
        effect: %{forest: -3, jaki: 1},
        tags: [:environment, :destruction]
      },
      %__MODULE__{
        id: :h_pesticide,
        type: :hitoyo,
        name: "農薬散布の季節",
        description: "虫を殺し、土を殺し、やがて人を蝕む。",
        flavor: "効率化の代償は、いのちの連鎖の断絶。",
        timing: :instant,
        category: :env_destruction,
        effect: %{forest: -2},
        tags: [:environment, :agriculture]
      },
      %__MODULE__{
        id: :h_plastic_sea,
        type: :hitoyo,
        name: "プラスチックの海",
        description: "便利の果てに、海が窒息していく。",
        flavor: "捨てられたものは、消えはしない。",
        timing: :instant,
        category: :env_destruction,
        effect: %{forest: -2, jaki: 1},
        tags: [:environment, :pollution]
      },

      # === 文化の切り捨て系 ===
      %__MODULE__{
        id: :h_festival_canceled,
        type: :hitoyo,
        name: "中止される小さな祭り",
        description: "「採算が取れない」その一言で、百年が消える。",
        flavor: "効率では測れないものがある。",
        timing: :instant,
        category: :cultural_cut,
        effect: %{culture: -2, social: -1},
        tags: [:culture, :festival]
      },
      %__MODULE__{
        id: :h_efficiency_wave,
        type: :hitoyo,
        name: "効率化の波",
        description: "手間のかかることが、次々と切り捨てられる。",
        flavor: "早く、安く、便利に。でも、大切なものは？",
        timing: :instant,
        category: :cultural_cut,
        effect: %{culture: -2},
        tags: [:culture, :efficiency]
      },

      # === 分断系 ===
      %__MODULE__{
        id: :h_sns_flame,
        type: :hitoyo,
        name: "炎上するSNS",
        description: "正義の名のもとに、人と人が引き裂かれる。",
        flavor: "画面の向こうにいるのも、人。",
        timing: :instant,
        category: :division,
        effect: %{social: -2, jaki: 1},
        tags: [:social, :conflict]
      },
      %__MODULE__{
        id: :h_generation_gap,
        type: :hitoyo,
        name: "世代間の断絶",
        description: "「最近の若者は」「老害が」憎み合う構造。",
        flavor: "つながりが断たれると、知恵も断たれる。",
        timing: :instant,
        category: :division,
        effect: %{social: -2, culture: -1},
        tags: [:social, :generation]
      },

      # === 物理的誘惑系 ===
      %__MODULE__{
        id: :h_endless_sale,
        type: :hitoyo,
        name: "底なしセール",
        description: "安い。だから買う。だからまた作る。終わらない。",
        flavor: "お得の裏側には、何がある？",
        timing: :delayed,
        category: :temptation,
        effect: %{currency: 1},
        condition: "今年中にF+1できなければ、年末にF-1, S-1",
        tags: [:economy, :consumption]
      },
      %__MODULE__{
        id: :h_24h_trap,
        type: :hitoyo,
        name: "24時間営業の罠",
        description: "便利は、誰かの犠牲の上に成り立っている。",
        flavor: "眠らない街は、誰かを眠らせない。",
        timing: :instant,
        category: :temptation,
        effect: %{social: -1, jaki: 1},
        tags: [:economy, :labor]
      },

      # === 邪気系 ===
      %__MODULE__{
        id: :h_apathy,
        type: :hitoyo,
        name: "無関心の蔓延",
        description: "「自分には関係ない」その言葉が、世界を蝕む。",
        flavor: "見て見ぬふりは、加担と同じ。",
        timing: :instant,
        category: :jaki,
        effect: %{jaki: 2},
        tags: [:jaki, :apathy]
      }
    ]
  end

  # --- 磨き（みがき）カード ---
  # 世界を「きれいにしていく」行動のカード
  # F/K/Sを回復させつつ、邪気を下げる効果を持つ
  defp migaki_cards do
    [
      # === 台所系 ===
      %__MODULE__{
        id: :m_miso,
        type: :migaki,
        name: "手前味噌を仕込む",
        description: "大豆を煮て、潰して、塩と麹を混ぜる。一年後の食卓を想いながら。",
        flavor: "発酵は、時間と微生物との対話。",
        cost: 2,
        category: :kitchen,
        effect: %{forest: 1, culture: 1, jaki: -1},
        tags: [:kitchen, :ferment, :handwork]
      },
      %__MODULE__{
        id: :m_nukadoko,
        type: :migaki,
        name: "糠床を育てる",
        description: "毎日、手を入れる。菌と対話する。",
        flavor: "見えないものを信じて、待つ。",
        cost: 1,
        category: :kitchen,
        effect: %{culture: 1, jaki: -1},
        tags: [:kitchen, :ferment]
      },
      %__MODULE__{
        id: :m_vegetable_table,
        type: :migaki,
        name: "野菜を育てて食卓にのせる",
        description: "種を蒔いて、水をやって、収穫して、料理する。一連の営み。",
        flavor: "土から食卓まで、いのちのリレー。",
        cost: 2,
        category: :kitchen,
        effect: %{forest: 2, social: 1, jaki: -1},
        tags: [:kitchen, :agriculture, :forest]
      },
      %__MODULE__{
        id: :m_dashi,
        type: :migaki,
        name: "出汁をひく",
        description: "昆布を水に浸し、鰹節を削る。この手間が、味を変える。",
        flavor: "丁寧さは、愛情の表れ。",
        cost: 1,
        category: :kitchen,
        effect: %{culture: 1, jaki: -1},
        tags: [:kitchen, :handwork]
      },

      # === 森系 ===
      %__MODULE__{
        id: :m_shrine_forest,
        type: :migaki,
        name: "鎮守の森のお手入れ",
        description: "落ち葉を掃き、枝を払い、神域を清める。",
        flavor: "森を守ることは、いのちを守ること。",
        cost: 2,
        category: :forest,
        effect: %{forest: 2, social: 1, jaki: -1},
        tags: [:forest, :community]
      },
      %__MODULE__{
        id: :m_firewood,
        type: :migaki,
        name: "薪を割る",
        description: "パカン、と割れる音。からだが温まる仕事。",
        flavor: "火を扱う知恵は、人を人たらしめる。",
        cost: 1,
        category: :forest,
        effect: %{forest: 1, jaki: -1},
        tags: [:forest, :handwork]
      },

      # === 祭り系 ===
      %__MODULE__{
        id: :m_small_festival,
        type: :migaki,
        name: "小さな祭りを続ける",
        description: "人が減っても、やめない。続けることに意味がある。",
        flavor: "祭りは、コミュニティの心臓の鼓動。",
        cost: 2,
        category: :festival,
        effect: %{culture: 2, social: 1, jaki: -1},
        tags: [:festival, :culture, :community],
        special: "「h_festival_canceled」の効果を無効化できる"
      },

      # === ケア系 ===
      %__MODULE__{
        id: :m_osusowake,
        type: :migaki,
        name: "お裾分けをする",
        description: "「これ、うちで採れたから」その一言が、つながりを紡ぐ。",
        flavor: "分かち合いは、豊かさを増やす魔法。",
        cost: 1,
        category: :care,
        effect: %{social: 2, jaki: -1},
        tags: [:care, :community]
      },
      %__MODULE__{
        id: :m_idobata,
        type: :migaki,
        name: "井戸端会議",
        description: "立ち話のなかに、大切な情報が流れている。",
        flavor: "何気ない会話が、コミュニティを支える。",
        cost: 0,
        category: :care,
        effect: %{social: 1, jaki: -1},
        tags: [:care, :dialogue, :community]
      },

      # === 大技 ===
      %__MODULE__{
        id: :m_ooharae,
        type: :migaki,
        name: "大祓（おおはらえ）",
        description: "半年分の穢れを、すべて祓い清める。",
        flavor: "清めの儀式は、心の再生。",
        cost: 4,
        category: :ritual,
        effect: %{culture: 2, jaki: -2},
        tags: [:festival, :culture]
      }
    ]
  end
end
