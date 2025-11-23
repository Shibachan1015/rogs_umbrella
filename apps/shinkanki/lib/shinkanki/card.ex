defmodule Shinkanki.Card do
  @moduledoc """
  Defines card structures for Action Cards and Talent Cards in Shinkanki.
  """

  @type card_type :: :action | :talent

  @type t :: %__MODULE__{
          id: atom(),
          type: card_type(),
          name: String.t(),
          description: String.t(),
          cost: integer(), # For action cards (P)
          # Base effect for action cards
          effect: map(),
          # Tags for compatibility (e.g., :nature, :craft, :community)
          tags: list(atom()),
          # For talent cards: tags they boost
          compatible_tags: list(atom())
        }

  defstruct [
    :id,
    :type,
    :name,
    :description,
    :cost,
    effect: %{},
    tags: [],
    compatible_tags: []
  ]

  @doc """
  Returns the list of all available cards (Actions and Talents).
  """
  def list_cards do
    list_actions() ++ list_talents()
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
  Gets a card by its ID.
  """
  def get_card(id) do
    Enum.find(list_cards(), &(&1.id == id))
  end

  @doc """
  Gets an action card by ID.
  """
  def get_action(id) do
    with %__MODULE__{type: :action} = card <- get_card(id) do
      card
    end
  end

  @doc """
  Gets a talent card by ID.
  """
  def get_talent(id) do
    with %__MODULE__{type: :talent} = card <- get_card(id) do
      card
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
        effect: %{social: 2, forest: 2}, # Reduce waste
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
end
