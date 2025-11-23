defmodule Shinkanki.Card do
  @moduledoc """
  Defines card structures for Action Cards and Talent Cards in Shinkanki.
  """

  @type card_type :: :action | :talent | :project | :event

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
          required_progress: integer()
        }

  defstruct [
    :id,
    :type,
    :name,
    :description,
    :cost,
    effect: %{},
    tags: [],
    compatible_tags: [],
    unlock_condition: %{},
    required_progress: 0
  ]

  @doc """
  Returns the list of all available cards (Actions, Talents, Projects, Events).
  """
  def list_cards do
    list_actions() ++ list_talents() ++ list_projects() ++ list_events()
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

  # --- Action Cards (行動カード) ---
  # Based on "Compatible Actions" from Talent descriptions
  defp actions do
    [
      # Forest / Nature related
      %__MODULE__{
        id: :shokurin,
        type: :action,
        name: "植林 (Reforestation)",
        description: "Plant trees to restore nature.",
        cost: 10,
        effect: %{forest: 5},
        tags: [:nature, :grow]
      },
      # Culture / Event related
      %__MODULE__{
        id: :saiji,
        type: :action,
        name: "祭事 (Festival)",
        description: "Celebrate to boost culture.",
        cost: 20,
        effect: %{culture: 5, social: 3},
        tags: [:event, :culture]
      },
      # Social / Community related
      %__MODULE__{
        id: :houshi,
        type: :action,
        name: "奉仕 (Service)",
        description: "Community service strengthens bonds.",
        cost: 0,
        effect: %{social: 5, currency: -5},
        tags: [:community, :care]
      },
      # Economic / Trade
      %__MODULE__{
        id: :koueki,
        type: :action,
        name: "交易 (Trade)",
        description: "Trade brings wealth.",
        cost: 10,
        effect: %{currency: 20, culture: -5},
        tags: [:biz, :logistics]
      },
      # Making / Craft
      %__MODULE__{
        id: :seisaku,
        type: :action,
        name: "制作 (Crafting)",
        description: "Make tools or art.",
        cost: 5,
        effect: %{culture: 3, currency: 5},
        tags: [:craft, :make]
      },
      # Repair
      %__MODULE__{
        id: :shuri,
        type: :action,
        name: "修理 (Repair)",
        description: "Fix broken things.",
        cost: 5,
        # Reduce waste
        effect: %{social: 2, forest: 2},
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
  defp projects do
    [
      %__MODULE__{
        id: :p_forest_fest,
        type: :project,
        name: "森の祝祭 (Forest Festival)",
        description: "A grand festival in the forest. Requires 4 talents to complete.",
        # High cost
        cost: 50,
        effect: %{forest: 10, culture: 10, social: 10},
        tags: [:event, :nature, :community],
        unlock_condition: %{forest: 80, culture: 60},
        required_progress: 4
      },
      %__MODULE__{
        id: :p_market,
        type: :project,
        name: "定期市 (Regular Market)",
        description: "Establish a regular market system. Requires 3 talents to complete.",
        cost: 30,
        effect: %{currency: 30, social: 5},
        tags: [:biz, :system],
        unlock_condition: %{social: 70},
        required_progress: 3
      }
    ]
  end

  # --- Event Cards (イベントカード) ---
  # 25 cards: disasters, festivals, divine blessings, old economy temptations
  defp events do
    [
      # === 災害系 (Disasters) - 8 cards ===
      %__MODULE__{
        id: :e_drought,
        type: :event,
        name: "大干ばつ (Great Drought)",
        description: "長い干ばつが森を枯らす。",
        effect: %{forest: -10, currency: -5},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_flood,
        type: :event,
        name: "大洪水 (Great Flood)",
        description: "洪水が文化遺産を破壊する。",
        effect: %{culture: -8, forest: -5},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_pestilence,
        type: :event,
        name: "疫病 (Pestilence)",
        description: "疫病がコミュニティを分断する。",
        effect: %{social: -10, culture: -5},
        tags: [:disaster, :community]
      },
      %__MODULE__{
        id: :e_wildfire,
        type: :event,
        name: "山火事 (Wildfire)",
        description: "山火事が森を焼き尽くす。",
        effect: %{forest: -15},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_cultural_loss,
        type: :event,
        name: "文化の喪失 (Cultural Loss)",
        description: "伝統が失われていく。",
        effect: %{culture: -12},
        tags: [:disaster, :culture]
      },
      %__MODULE__{
        id: :e_conflict,
        type: :event,
        name: "対立 (Conflict)",
        description: "コミュニティ内で対立が起きる。",
        effect: %{social: -12, currency: -10},
        tags: [:disaster, :community]
      },
      %__MODULE__{
        id: :e_erosion,
        type: :event,
        name: "土壌流失 (Soil Erosion)",
        description: "土壌が失われ、森が弱る。",
        effect: %{forest: -8, culture: -3},
        tags: [:disaster, :nature]
      },
      %__MODULE__{
        id: :e_isolation,
        type: :event,
        name: "孤立 (Isolation)",
        description: "人々が孤立し、つながりが薄れる。",
        effect: %{social: -8, forest: -3},
        tags: [:disaster, :community]
      },

      # === 祭り・祝福系 (Festivals & Blessings) - 10 cards ===
      %__MODULE__{
        id: :e_harvest_festival,
        type: :event,
        name: "収穫祭 (Harvest Festival)",
        description: "豊作を祝う祭りが開かれる。",
        effect: %{forest: 8, culture: 5, social: 5},
        tags: [:festival, :nature]
      },
      %__MODULE__{
        id: :e_cultural_festival,
        type: :event,
        name: "文化祭 (Cultural Festival)",
        description: "文化を祝う祭りが開かれる。",
        effect: %{culture: 10, social: 5},
        tags: [:festival, :culture]
      },
      %__MODULE__{
        id: :e_community_gathering,
        type: :event,
        name: "コミュニティの集い (Community Gathering)",
        description: "人々が集まり、絆を深める。",
        effect: %{social: 10, culture: 3},
        tags: [:festival, :community]
      },
      %__MODULE__{
        id: :e_divine_blessing,
        type: :event,
        name: "神々の加護 (Divine Blessing)",
        description: "神々が世界に祝福を与える。",
        effect: %{forest: 5, culture: 5, social: 5, currency: 10},
        tags: [:blessing, :divine]
      },
      %__MODULE__{
        id: :e_rain,
        type: :event,
        name: "恵みの雨 (Blessing Rain)",
        description: "恵みの雨が森を潤す。",
        effect: %{forest: 12},
        tags: [:blessing, :nature]
      },
      %__MODULE__{
        id: :e_artistic_awakening,
        type: :event,
        name: "芸術の目覚め (Artistic Awakening)",
        description: "新しい芸術が生まれる。",
        effect: %{culture: 12},
        tags: [:blessing, :culture]
      },
      %__MODULE__{
        id: :e_unity,
        type: :event,
        name: "結束 (Unity)",
        description: "人々が結束し、力を合わせる。",
        effect: %{social: 12, currency: 5},
        tags: [:blessing, :community]
      },
      %__MODULE__{
        id: :e_nature_recovery,
        type: :event,
        name: "自然の回復 (Nature Recovery)",
        description: "自然が回復し始める。",
        effect: %{forest: 8, culture: 3},
        tags: [:blessing, :nature]
      },
      %__MODULE__{
        id: :e_tradition_revival,
        type: :event,
        name: "伝統の復興 (Tradition Revival)",
        description: "古い伝統が再び息づく。",
        effect: %{culture: 8, social: 3},
        tags: [:blessing, :culture]
      },
      %__MODULE__{
        id: :e_mutual_aid,
        type: :event,
        name: "相互扶助 (Mutual Aid)",
        description: "人々が互いに助け合う。",
        effect: %{social: 8, forest: 3},
        tags: [:blessing, :community]
      },

      # === 旧経済の誘惑 (Old Economy Temptations) - 4 cards ===
      %__MODULE__{
        id: :e_quick_profit,
        type: :event,
        name: "急な利益 (Quick Profit)",
        description: "短期的な利益がもたらされるが、代償がある。",
        effect: %{currency: 30, forest: -5, culture: -5},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_industrial_boom,
        type: :event,
        name: "産業ブーム (Industrial Boom)",
        description: "産業が発展するが、環境に負担がかかる。",
        effect: %{currency: 25, forest: -8, social: -3},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_speculation,
        type: :event,
        name: "投機 (Speculation)",
        description: "投機で一時的な富が生まれるが、不安定さが増す。",
        effect: %{currency: 20, social: -8, culture: -3},
        tags: [:temptation, :economy]
      },
      %__MODULE__{
        id: :e_short_term_gain,
        type: :event,
        name: "短期的な利益 (Short-term Gain)",
        description: "短期的な利益がもたらされるが、長期的な損失がある。",
        effect: %{currency: 15, forest: -3, culture: -3, social: -3},
        tags: [:temptation, :economy]
      },

      # === 特殊イベント (Special Events) - 3 cards ===
      %__MODULE__{
        id: :e_balance,
        type: :event,
        name: "調和 (Balance)",
        description: "すべてが調和し、バランスが取れる。",
        effect: %{forest: 5, culture: 5, social: 5, currency: 10},
        tags: [:special, :balance]
      },
      %__MODULE__{
        id: :e_windfall,
        type: :event,
        name: "予期せぬ収入 (Windfall)",
        description: "予期せぬ収入が入る。",
        effect: %{currency: 20},
        tags: [:special, :economy]
      },
      %__MODULE__{
        id: :e_wisdom,
        type: :event,
        name: "知恵の光 (Light of Wisdom)",
        description: "古い知恵が新たな光を放つ。",
        effect: %{culture: 8, social: 5, currency: 5},
        tags: [:special, :wisdom]
      }
    ]
  end
end
