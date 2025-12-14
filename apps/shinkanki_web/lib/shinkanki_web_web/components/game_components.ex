defmodule ShinkankiWebWeb.GameComponents do
  use Phoenix.Component

  import ShinkankiWebWeb.CoreComponents
  alias Phoenix.LiveView.JS

  @doc """
  Renders a card looking like an "Ofuda" (Talisman).
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :cost, :integer, default: 0
  attr :type, :atom, default: :action, values: [:action, :reaction, :event]
  attr :class, :string, default: nil
  attr :rest, :global

  def ofuda_card(assigns) do
    disabled =
      assigns[:rest][:"aria-disabled"] == true || assigns[:rest][:"aria-disabled"] == "true"

    assigns = assign(assigns, :disabled, disabled)

    ~H"""
    <div
      class={[
        "ofuda-card relative w-14 h-20 sm:w-20 sm:h-28 md:w-24 md:h-36 flex flex-col items-center p-1 sm:p-1.5 md:p-2 transition-all select-none state-layer focus-ring bg-washi border border-sumi/30 rounded-md sm:rounded-lg shadow-md",
        if(@disabled,
          do: "ofuda-card--disabled cursor-not-allowed",
          else: "cursor-pointer hover:-translate-y-1 sm:hover:-translate-y-2 active:scale-95"
        ),
        @class
      ]}
      style={
        if @disabled,
          do: "",
          else: "transition: all var(--motion-duration-short4) var(--motion-easing-standard);"
      }
      role="button"
      tabindex={if @disabled, do: "-1", else: "0"}
      aria-label={"カード: #{@title}, コスト: #{@cost}"}
      aria-disabled={@disabled}
      {@rest}
    >
      <div class="w-full border-b border-sumi pb-0.5 sm:pb-1 text-center overflow-hidden">
        <span class="writing-mode-vertical text-[8px] sm:text-[10px] md:text-xs font-serif font-bold text-sumi tracking-tight sm:tracking-widest line-clamp-2">
          {String.slice(@title, 0, 4)}
        </span>
      </div>

      <div class="flex-1 flex items-center justify-center py-0.5 sm:py-1 md:py-2">
        <div class={[
          "w-6 h-6 sm:w-8 sm:h-8 md:w-12 md:h-12 rounded-full border border-sumi flex items-center justify-center text-sm sm:text-lg md:text-2xl font-serif",
          @type == :action && "text-shu bg-shu/5",
          @type == :reaction && "text-matsu bg-matsu/5",
          @type == :event && "text-sumi bg-sumi/5"
        ]}>
          {String.first(@title)}
        </div>
      </div>

      <div class="w-full border-t border-sumi pt-0.5 sm:pt-1 flex justify-center items-end">
        <span class="text-[7px] sm:text-[8px] md:text-[10px] text-sumi/60 font-mono">{@cost}</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button looking like a "Hanko" (Stamp).
  """
  attr :label, :string, required: true
  attr :color, :string, default: "shu", values: ["shu", "sumi", "matsu"]
  attr :class, :string, default: nil
  attr :rest, :global

  def hanko_btn(assigns) do
    ~H"""
    <button
      class={[
        "hanko-btn flex items-center justify-center state-layer ripple focus-ring",
        @color == "shu" && "text-shu border-shu/60",
        @color == "sumi" && "text-sumi border-sumi/50",
        @color == "matsu" && "text-matsu border-matsu/60",
        @class
      ]}
      style="transition: all var(--motion-duration-short4) var(--motion-easing-standard);"
      aria-label={@label}
      {@rest}
    >
      <span class="font-serif font-bold text-xs md:text-sm writing-mode-vertical leading-none transition-transform duration-200">
        {@label}
      </span>
    </button>
    """
  end

  @doc """
  Renders a phase indicator showing the current game phase.
  """
  attr :current_phase, :atom,
    required: true,
    values: [
      :hitoyo,
      :kamihakari,
      :itonami,
      :kokyu,
      :musuhi,
      :toshiokuri,
      :event,
      :discussion,
      :action,
      :demurrage,
      :life_update,
      :judgment
    ]

  attr :class, :string, default: nil
  attr :rest, :global

  def phase_indicator(assigns) do
    # New rulebook-compliant phases
    new_phases = [
      {:hitoyo, "人代", "邪気に応じた人代カードをめくる"},
      {:kamihakari, "神議り", "プレイヤー全員で方針を相談する"},
      {:itonami, "営み", "営みカードを選択し、実行する"},
      {:kokyu, "呼吸", "空環の還流（P≧5は必須）"},
      {:musuhi, "結び", "むすひチップを仲間へ贈る"},
      {:toshiokuri, "年送り", "ターン終了・判定"}
    ]

    # Legacy phases for backward compatibility
    legacy_phases = [
      {:event, "イベント", "イベントカードを1枚めくり、効果を適用する"},
      {:discussion, "相談", "プレイヤー全員で方針を相談する"},
      {:action, "アクション", "アクションカードを選択し、実行する"},
      {:demurrage, "減衰", "空環ポイント(P)の減衰処理"},
      {:life_update, "生命更新", "L = F + K + S を再計算"},
      {:judgment, "判定", "ゲームオーバー条件のチェック"}
    ]

    # Choose phases based on current phase
    phases =
      if assigns.current_phase in [:hitoyo, :kamihakari, :itonami, :kokyu, :musuhi, :toshiokuri] do
        new_phases
      else
        legacy_phases
      end

    assigns = assign(assigns, :phases, phases)

    ~H"""
    <div class={["phase-indicator", @class]} role="region" aria-label="ゲームフェーズ" {@rest}>
      <div class="flex items-center justify-center gap-1 sm:gap-2 md:gap-3 mb-3 flex-wrap">
        <%= for {{phase, name, _desc}, index} <- Enum.with_index(@phases) do %>
          <% current_index = Enum.find_index(@phases, fn {p, _, _} -> p == @current_phase end) || 0
          is_current = phase == @current_phase
          is_past = index < current_index %>
          <div class="flex flex-col items-center gap-1 relative">
            <div
              class={[
                "w-10 h-10 sm:w-12 sm:h-12 md:w-14 md:h-14 rounded-full border-2 flex items-center justify-center text-sm sm:text-base md:text-lg font-bold transition-all duration-500 relative z-10",
                if(is_current,
                  do:
                    "border-shu bg-shu/20 text-shu scale-110 shadow-lg ring-4 ring-shu/20 animate-pulse",
                  else:
                    if(is_past,
                      do: "border-matsu bg-matsu/10 text-matsu scale-100 shadow-sm",
                      else: "border-sumi/30 bg-washi text-sumi/50 scale-100"
                    )
                )
              ]}
              aria-current={if(is_current, do: "step", else: "false")}
              aria-label={"フェーズ #{index + 1}: #{name}"}
              data-phase={phase}
            >
              <%= if is_past do %>
                <span class="text-matsu text-lg sm:text-xl">✓</span>
              <% else %>
                <span>{index + 1}</span>
              <% end %>
            </div>
            <span class={[
              "text-[10px] sm:text-xs font-semibold uppercase tracking-[0.2em] text-center max-w-[60px] sm:max-w-none",
              if(is_current,
                do: "text-shu font-bold",
                else: if(is_past, do: "text-matsu", else: "text-sumi/40")
              )
            ]}>
              {name}
            </span>
            <%= if index < length(@phases) - 1 do %>
              <div
                class={[
                  "hidden sm:block absolute top-5 sm:top-6 md:top-7 left-full w-4 sm:w-6 md:w-8 h-0.5 transition-all duration-500 z-0",
                  if(is_past || is_current, do: "bg-matsu/50", else: "bg-sumi/20")
                ]}
                aria-hidden="true"
                style="transform: translateX(-50%);"
              >
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="text-center animate-fade-in">
        <%= for {phase, name, desc} <- @phases do %>
          <%= if phase == @current_phase do %>
            <div class="px-4 py-3 bg-washi border-2 border-shu/30 rounded-lg shadow-lg backdrop-blur-sm">
              <div class="text-base sm:text-lg md:text-xl font-bold text-shu mb-2 flex items-center justify-center gap-2">
                <span class="inline-block w-2 h-2 bg-shu rounded-full animate-pulse"></span>
                {name}フェーズ
                <span class="inline-block w-2 h-2 bg-shu rounded-full animate-pulse"></span>
              </div>
              <div class="text-xs sm:text-sm text-sumi/80 leading-relaxed">{desc}</div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders an event card with detailed information.
  Used in the Event Phase to display the current event.
  """
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :effect, :map, default: %{}

  attr :category, :atom,
    default: :neutral,
    values: [:disaster, :festival, :blessing, :temptation, :neutral]

  attr :class, :string, default: nil
  attr :rest, :global

  def event_card(assigns) do
    category_colors = %{
      disaster: "event-card--disaster",
      festival: "event-card--festival",
      blessing: "event-card--blessing",
      temptation: "event-card--temptation",
      neutral: "event-card--neutral"
    }

    category_icon = %{
      disaster: "⚡",
      festival: "🎉",
      blessing: "✨",
      temptation: "💰",
      neutral: "📜"
    }

    border_color = Map.get(category_colors, assigns.category, category_colors.neutral)
    icon = Map.get(category_icon, assigns.category, category_icon.neutral)

    assigns =
      assigns
      |> assign(:border_color, border_color)
      |> assign(:icon, icon)

    ~H"""
    <div
      class={[
        "resonance-card event-card relative w-full max-w-md mx-auto p-3 sm:p-6 transition-all duration-300",
        @border_color,
        @class
      ]}
      role="article"
      aria-label={"イベントカード: #{@title}"}
      {@rest}
    >
      <!-- Header - Mobile: Compact, Desktop: Full -->
      <div class="flex items-center justify-between mb-2 sm:mb-4 pb-2 sm:pb-3 border-b-2 border-sumi/30">
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="text-xl sm:text-3xl">{@icon}</div>
          <h3 class="text-base sm:text-xl font-bold text-sumi">
            {@title}
          </h3>
        </div>
        <div class="text-[10px] sm:text-xs uppercase tracking-[0.2em] sm:tracking-[0.3em] text-sumi/50">
          イベント
        </div>
      </div>
      
    <!-- Description - Mobile: Shorter, Desktop: Full -->
      <div class="mb-2 sm:mb-4">
        <p class="text-xs sm:text-sm leading-relaxed text-sumi line-clamp-3 sm:line-clamp-none">
          {@description}
        </p>
      </div>
      
    <!-- Effect Display - Mobile: Compact grid, Desktop: Full -->
      <%= if map_size(@effect) > 0 do %>
        <div class="mt-2 sm:mt-4 pt-2 sm:pt-4 border-t border-sumi/20">
          <div class="text-[10px] sm:text-xs uppercase tracking-[0.15em] sm:tracking-[0.2em] text-sumi/60 mb-1.5 sm:mb-2">
            効果
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-1.5 sm:gap-2 text-center">
            <%= if Map.has_key?(@effect, :forest) or Map.has_key?(@effect, :f) do %>
              <div class="bg-matsu/10 border border-matsu/30 rounded p-1.5 sm:p-2">
                <div class="text-[8px] sm:text-[10px] text-matsu/70 mb-0.5 sm:mb-1">🌲 森</div>
                <div class="text-xs sm:text-sm font-bold text-matsu">
                  {format_effect_value(@effect[:forest] || @effect[:f])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :culture) or Map.has_key?(@effect, :k) do %>
              <div class="bg-sakura/10 border border-sakura/30 rounded p-1.5 sm:p-2">
                <div class="text-[8px] sm:text-[10px] text-sakura/70 mb-0.5 sm:mb-1">🎭 文化</div>
                <div class="text-xs sm:text-sm font-bold text-sakura">
                  {format_effect_value(@effect[:culture] || @effect[:k])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :social) or Map.has_key?(@effect, :s) do %>
              <div class="bg-kohaku/10 border border-kohaku/30 rounded p-1.5 sm:p-2">
                <div class="text-[8px] sm:text-[10px] text-kohaku/70 mb-0.5 sm:mb-1">🤝 社会</div>
                <div class="text-xs sm:text-sm font-bold text-kohaku">
                  {format_effect_value(@effect[:social] || @effect[:s])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :currency) or Map.has_key?(@effect, :p) do %>
              <div class="bg-kin/10 border border-kin/30 rounded p-1.5 sm:p-2">
                <div class="text-[8px] sm:text-[10px] text-kin/70 mb-0.5 sm:mb-1">✨ 空環</div>
                <div class="text-xs sm:text-sm font-bold text-kin">
                  {format_effect_value(@effect[:currency] || @effect[:p])}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_effect_value(value) when is_integer(value) do
    if value >= 0, do: "+#{value}", else: "#{value}"
  end

  defp format_effect_value(value), do: to_string(value)

  @doc """
  Renders a modal for displaying event card details.
  """
  attr :show, :boolean, default: false
  attr :event, :map, default: nil
  attr :id, :string, default: "event-modal"
  attr :rest, :global

  def event_modal(assigns) do
    ~H"""
    <%= if @show && @event do %>
      <div
        id={@id}
        class="hitoyo-overlay"
        role="dialog"
        aria-modal="true"
        aria-labelledby="hitoyo-modal-title"
        {@rest}
      >
        <div class="hitoyo-mist"></div>
        <div class="hitoyo-card-container">
          <div class="hitoyo-card">
            <div class="hitoyo-header">
              <div class="hitoyo-label">人代カード</div>
              <div class="hitoyo-icon">{get_hitoyo_icon(@event)}</div>
              <h2 id="hitoyo-modal-title" class="hitoyo-title">
                {@event[:title] || @event["title"] || "災厄"}
              </h2>
            </div>

            <div class="hitoyo-description">
              {@event[:description] || @event["description"] || "世界に災いが降りかかる..."}
            </div>

            <div class="hitoyo-effects">
              <%= if get_effect_value(@event, :forest) || get_effect_value(@event, :f) do %>
                <div class="hitoyo-effect">
                  <span class="hitoyo-effect-label">森</span>
                  <span class={[
                    "hitoyo-effect-value",
                    if((get_effect_value(@event, :forest) || get_effect_value(@event, :f) || 0) > 0,
                      do: "positive"
                    )
                  ]}>
                    {format_hitoyo_effect(
                      get_effect_value(@event, :forest) || get_effect_value(@event, :f)
                    )}
                  </span>
                </div>
              <% end %>
              <%= if get_effect_value(@event, :culture) || get_effect_value(@event, :k) do %>
                <div class="hitoyo-effect">
                  <span class="hitoyo-effect-label">文化</span>
                  <span class={[
                    "hitoyo-effect-value",
                    if((get_effect_value(@event, :culture) || get_effect_value(@event, :k) || 0) > 0,
                      do: "positive"
                    )
                  ]}>
                    {format_hitoyo_effect(
                      get_effect_value(@event, :culture) || get_effect_value(@event, :k)
                    )}
                  </span>
                </div>
              <% end %>
              <%= if get_effect_value(@event, :social) || get_effect_value(@event, :s) do %>
                <div class="hitoyo-effect">
                  <span class="hitoyo-effect-label">社会</span>
                  <span class={[
                    "hitoyo-effect-value",
                    if((get_effect_value(@event, :social) || get_effect_value(@event, :s) || 0) > 0,
                      do: "positive"
                    )
                  ]}>
                    {format_hitoyo_effect(
                      get_effect_value(@event, :social) || get_effect_value(@event, :s)
                    )}
                  </span>
                </div>
              <% end %>
              <%= if get_effect_value(@event, :evil) || get_effect_value(@event, :jaki) do %>
                <div class="hitoyo-effect">
                  <span class="hitoyo-effect-label">邪気</span>
                  <span class={[
                    "hitoyo-effect-value",
                    if((get_effect_value(@event, :evil) || get_effect_value(@event, :jaki) || 0) < 0,
                      do: "positive"
                    )
                  ]}>
                    {format_hitoyo_effect(
                      get_effect_value(@event, :evil) || get_effect_value(@event, :jaki)
                    )}
                  </span>
                </div>
              <% end %>
            </div>

            <button
              class="hitoyo-confirm-btn"
              phx-click="close_event_modal"
            >
              受け入れる
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_hitoyo_icon(event) do
    category = event[:category] || event["category"] || :disaster

    case category do
      :disaster -> "💀"
      "disaster" -> "💀"
      :temptation -> "🐍"
      "temptation" -> "🐍"
      :division -> "⚔️"
      "division" -> "⚔️"
      :corruption -> "🕷️"
      "corruption" -> "🕷️"
      _ -> "👹"
    end
  end

  defp get_effect_value(event, key) do
    effect = event[:effect] || event["effect"] || %{}
    effect[key] || effect[to_string(key)]
  end

  defp format_hitoyo_effect(nil), do: ""

  defp format_hitoyo_effect(value) when is_integer(value) do
    if value >= 0, do: "+#{value}", else: "#{value}"
  end

  defp format_hitoyo_effect(value), do: to_string(value)

  @doc """
  Renders a talent card - a smaller card that can be stacked on action cards.
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :compatible_tags, :list, default: []
  attr :is_selected, :boolean, default: false
  attr :is_used, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def talent_card(assigns) do
    ~H"""
    <div
      class={[
        "talent-card-shell relative w-16 h-20 flex flex-col items-center p-1.5 transition-all duration-300 select-none",
        if(@is_used,
          do: "cursor-not-allowed opacity-40",
          else:
            if(@is_selected,
              do: "cursor-pointer ring-2 ring-kin border border-kin scale-110 z-20",
              else:
                "cursor-pointer hover:-translate-y-1 hover:shadow-md hover:border-kin/70 active:scale-95"
            )
        ),
        "focus:outline-none focus:ring-2 focus:ring-kin/50 focus:ring-offset-1",
        @class
      ]}
      role="button"
      tabindex={if @is_used, do: "-1", else: "0"}
      aria-label={"才能カード: #{@title}"}
      aria-disabled={@is_used}
      {@rest}
    >
      <div class="w-full border-b border-kin/30 pb-0.5 text-center">
        <span class="writing-mode-vertical text-[9px] font-serif font-bold text-kin tracking-wider leading-tight">
          {@title}
        </span>
      </div>

      <div class="flex-1 flex items-center justify-center py-1">
        <div class="w-8 h-8 rounded-full border border-kin/50 flex items-center justify-center text-lg font-serif text-kin bg-kin/5">
          {String.first(@title)}
        </div>
      </div>

      <%= if @is_used do %>
        <div class="absolute inset-0 bg-sumi/20 flex items-center justify-center">
          <span class="text-xs text-sumi/60 font-bold">使用済</span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an action card with talent cards stacked on top.
  Shows up to 2 talent cards stacked.
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :cost, :integer, default: 0
  attr :type, :atom, default: :action, values: [:action, :reaction, :event]
  attr :talent_cards, :list, default: []
  attr :tags, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global

  def action_card_with_talents(assigns) do
    talent_count = length(assigns.talent_cards)
    bonus = min(talent_count, 2)

    assigns = assign(assigns, :talent_count, talent_count)
    assigns = assign(assigns, :bonus, bonus)

    ~H"""
    <div class={["relative", @class]} {@rest}>
      <!-- Base Action Card -->
      <.ofuda_card
        title={@title}
        description={@description}
        cost={@cost}
        type={@type}
        class="relative z-0"
      />
      
    <!-- Talent Cards Stacked -->
      <%= if @talent_count > 0 do %>
        <div class="absolute -top-2 -right-2 z-10 flex flex-col gap-0.5">
          <%= for {talent, index} <- Enum.with_index(Enum.take(@talent_cards, 2)) do %>
            <div
              class={[
                "talent-stack-wrapper relative transform transition-all duration-300",
                if(index > 0, do: "-mt-4 translate-x-1", else: "")
              ]}
              style={if index > 0, do: "z-index: #{10 - index};", else: ""}
            >
              <.talent_card
                title={talent[:title] || talent["title"] || "才能"}
                description={talent[:description] || talent["description"]}
                compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
                class="w-12 h-14 text-[8px] shadow-lg border-2 border-kin"
              />
              <%= if index == 0 && @talent_count > 2 do %>
                <div class="absolute -bottom-1 -right-1 w-4 h-4 bg-kin rounded-full border-2 border-sumi flex items-center justify-center text-[7px] font-bold text-sumi shadow-md">
                  +{@talent_count - 2}
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Bonus Indicator with Animation -->
        <div class="absolute -bottom-1 -left-1 w-7 h-7 bg-kin rounded-full border-2 border-sumi flex items-center justify-center text-xs font-bold text-sumi shadow-lg animate-pulse">
          <span class="relative z-10">+{@bonus}</span>
          <div class="absolute inset-0 bg-kin/30 rounded-full animate-ping"></div>
        </div>
        
    <!-- Talent Stack Indicator -->
        <div class="absolute top-1 left-1 bg-kin/90 text-washi text-[8px] px-1.5 py-0.5 rounded-full font-bold shadow-md">
          {if @talent_count >= 2, do: "最大", else: ""}才能{@talent_count}枚
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a talent card selection area for choosing talents to stack on an action card.
  """
  attr :available_talents, :list, required: true
  attr :selected_talent_ids, :list, default: []
  attr :action_card_tags, :list, default: []
  attr :max_selection, :integer, default: 2
  attr :id, :string, default: "talent-selector"
  attr :rest, :global

  def talent_selector(assigns) do
    compatible_talents =
      Enum.filter(assigns.available_talents, fn talent ->
        talent_tags = talent[:compatible_tags] || talent["compatible_tags"] || []
        Enum.any?(talent_tags, &Enum.member?(assigns.action_card_tags, &1))
      end)

    assigns = assign(assigns, :compatible_talents, compatible_talents)

    ~H"""
    <div
      id={@id}
      class="resonance-modal-frame border border-kin/40 p-3 sm:p-5 max-w-md text-[var(--color-landing-text-primary)]"
      role="dialog"
      aria-label="才能カード選択"
      {@rest}
    >
      <div class="mb-2 sm:mb-3">
        <h3 class="text-xs sm:text-sm font-bold mb-1 tracking-[0.1em] sm:tracking-[0.2em]">
          才能選択（最大{@max_selection}枚）
        </h3>
        <p class="text-[10px] sm:text-xs text-[var(--color-landing-text-secondary)] hidden sm:block">
          アクションカードに重ねて効果を強化
        </p>
      </div>

      <%= if length(@compatible_talents) == 0 do %>
        <div class="text-center py-3 sm:py-4 text-sumi/50 text-xs sm:text-sm">
          互換性のある才能カードがありません
        </div>
      <% else %>
        <!-- Mobile: Simple list view, Desktop: Grid -->
        <div class="sm:hidden space-y-1.5 max-h-40 overflow-y-auto">
          <%= for talent <- @compatible_talents do %>
            <% talent_id =
              talent[:player_talent_id] || talent["player_talent_id"] || talent[:id] || talent["id"]

            is_selected = Enum.member?(@selected_talent_ids, talent_id)
            is_used = talent[:is_used] || talent["is_used"] || false
            can_select = (length(@selected_talent_ids) < @max_selection || is_selected) && not is_used %>
            <button
              type="button"
              phx-click={if can_select, do: "toggle_talent", else: nil}
              phx-value-talent-id={talent_id}
              disabled={not can_select}
              class={"w-full flex items-center justify-between p-2 rounded-lg transition-all active:scale-98 " <>
                if(is_selected, do: "bg-kin/20 ring-2 ring-kin ", else: "bg-white/5 ") <>
                if(can_select, do: "hover:bg-white/10", else: "opacity-40")}
            >
              <div class="flex items-center gap-2">
                <span class="text-base">✨</span>
                <span class="text-sm font-medium text-[var(--color-landing-pale)]">
                  {talent[:name] || talent["name"] || "才能"}
                </span>
              </div>
              <%= if is_selected do %>
                <span class="text-kin text-sm">✓</span>
              <% end %>
            </button>
          <% end %>
        </div>
        
    <!-- Desktop: Grid view -->
        <div class="hidden sm:grid grid-cols-3 gap-2 max-h-48 overflow-y-auto scrollbar-thin">
          <%= for talent <- @compatible_talents do %>
            <% talent_id =
              talent[:player_talent_id] || talent["player_talent_id"] || talent[:id] || talent["id"]

            is_selected = Enum.member?(@selected_talent_ids, talent_id)
            is_used = talent[:is_used] || talent["is_used"] || false
            can_select = (length(@selected_talent_ids) < @max_selection || is_selected) && not is_used %>
            <.talent_card
              title={talent[:name] || talent["name"] || "才能"}
              description={talent[:description] || talent["description"]}
              compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
              is_selected={is_selected}
              class={
                join_class([
                  "w-full",
                  if(not can_select, do: "opacity-50 cursor-not-allowed", else: ""),
                  if(is_used, do: "grayscale", else: "")
                ])
              }
              phx-click={if can_select, do: "toggle_talent", else: nil}
              phx-value-talent-id={talent_id}
            />
          <% end %>
        </div>
      <% end %>
      
    <!-- Action Buttons - Large tap targets for mobile -->
      <div class="mt-2 sm:mt-3 pt-2 sm:pt-3 border-t border-white/10">
        <%= if length(@selected_talent_ids) > 0 do %>
          <div class="text-[10px] sm:text-xs text-[var(--color-landing-text-secondary)] mb-1.5 sm:mb-2">
            選択中: {length(@selected_talent_ids)} / {@max_selection}
          </div>
        <% end %>
        <div class="flex flex-col sm:flex-row gap-1.5 sm:gap-2" phx-click-stop>
          <button
            type="button"
            class="flex-1 py-2.5 sm:py-2 px-4 rounded-lg bg-kin text-[var(--color-midnight)] font-bold text-sm sm:text-base transition-all active:scale-95"
            phx-click="confirm_talent_selection"
          >
            {if length(@selected_talent_ids) > 0, do: "確定", else: "なしで続行"}
          </button>
          <button
            type="button"
            class="flex-1 py-2 sm:py-2 px-4 rounded-lg border border-white/30 text-white/80 text-sm transition-all hover:bg-white/10"
            phx-click="cancel_talent_selection"
          >
            キャンセル
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a project card - a collaborative project that players work on together.
  """
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :cost, :integer, required: true
  attr :progress, :integer, default: 0
  attr :effect, :map, default: %{}
  attr :unlock_condition, :map, default: %{}
  attr :is_unlocked, :boolean, default: false
  attr :is_completed, :boolean, default: false
  attr :contributed_talents, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global

  def project_card(assigns) do
    progress_percentage =
      if assigns.cost > 0, do: min(100, trunc(assigns.progress / assigns.cost * 100)), else: 0

    is_unlockable = check_unlock_condition(assigns.unlock_condition, assigns)

    assigns =
      assigns
      |> assign(:progress_percentage, progress_percentage)
      |> assign(:is_unlockable, is_unlockable)

    assigns = assign(assigns, :project_state_class, project_state_classes(assigns))

    ~H"""
    <div
      class={[
        "project-card-shell relative w-full max-w-sm p-5 transition-all duration-300 overflow-hidden text-[var(--color-landing-text-primary)]",
        @project_state_class,
        @class
      ]}
      role="article"
      aria-label={"プロジェクトカード: #{@title}"}
      {@rest}
    >
      <!-- Header -->
      <div class="flex items-center justify-between mb-3 pb-2 border-b border-white/10">
        <div class="flex items-center gap-2 flex-1">
          <div class="text-2xl drop-shadow">
            {if @is_completed, do: "✨", else: if(@is_unlocked, do: "🏗️", else: "🔒")}
          </div>
          <h3 class="text-base sm:text-lg font-bold writing-mode-vertical flex-1 tracking-[0.3em]">
            {@title}
          </h3>
        </div>
        <div class="text-[10px] sm:text-xs uppercase tracking-[0.3em] text-sumi/50">
          プロジェクト
        </div>
      </div>
      
    <!-- Status Badge -->
      <%= if @is_completed do %>
        <div class="absolute top-2 right-2 bg-kin text-washi text-[10px] px-2 py-1 rounded-full font-bold shadow-md tracking-[0.2em]">
          完成
        </div>
      <% else %>
        <%= if @is_unlocked do %>
          <div class="absolute top-2 right-2 bg-matsu/20 text-matsu text-[10px] px-2 py-1 rounded-full font-bold border border-matsu/30 tracking-[0.2em]">
            進行中
          </div>
        <% end %>
      <% end %>
      
    <!-- Description -->
      <div class="mb-3">
        <p class="text-sm leading-relaxed text-[var(--color-landing-text-secondary)]">
          {@description}
        </p>
      </div>
      
    <!-- Unlock Condition -->
      <%= if not @is_unlocked && map_size(@unlock_condition) > 0 do %>
        <div class="mb-3 p-2 bg-white/5 border border-white/10 rounded">
          <div class="text-xs uppercase tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-1">
            アンロック条件
          </div>
          <div class="flex gap-2 text-xs">
            <%= if Map.has_key?(@unlock_condition, :forest) or Map.has_key?(@unlock_condition, :f) do %>
              <span class="text-matsu font-semibold">
                F: {Map.get(@unlock_condition, :forest, Map.get(@unlock_condition, :f, 0))}
              </span>
            <% end %>
            <%= if Map.has_key?(@unlock_condition, :culture) or Map.has_key?(@unlock_condition, :k) do %>
              <span class="text-sakura font-semibold">
                K: {Map.get(@unlock_condition, :culture, Map.get(@unlock_condition, :k, 0))}
              </span>
            <% end %>
            <%= if Map.has_key?(@unlock_condition, :social) or Map.has_key?(@unlock_condition, :s) do %>
              <span class="text-kohaku font-semibold">
                S: {Map.get(@unlock_condition, :social, Map.get(@unlock_condition, :s, 0))}
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
      
    <!-- Progress Bar -->
      <%= if @is_unlocked && not @is_completed do %>
        <div class="mb-3">
          <div class="flex justify-between items-center mb-1">
            <span class="text-xs text-[var(--color-landing-text-secondary)] font-semibold tracking-[0.2em]">
              進捗状況
            </span>
            <span class="text-xs font-bold text-[var(--color-landing-pale)]">
              {@progress} / {@cost}
            </span>
          </div>
          <div
            class="project-progress-track"
            role="progressbar"
            aria-valuenow={@progress}
            aria-valuemin="0"
            aria-valuemax={@cost}
          >
            <div class="project-progress-fill" style={"width: #{@progress_percentage}%"}></div>
            <span class="project-progress-value">
              {@progress_percentage}%
            </span>
          </div>
          <%= if @progress_percentage >= 100 do %>
            <div class="mt-2 text-center">
              <span class="text-xs font-bold text-kin animate-pulse tracking-[0.2em]">
                ✨ 完成間近！ ✨
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
      
    <!-- Contributed Talents -->
      <%= if length(@contributed_talents) > 0 do %>
        <div class="mb-3 pt-2 border-t border-white/10">
          <div class="text-xs uppercase tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-2">
            捧げられた才能
          </div>
          <div class="flex flex-wrap gap-1">
            <%= for talent <- @contributed_talents do %>
              <div class="px-2 py-1 bg-kin/10 border border-kin/30 rounded text-[10px] text-kin font-semibold">
                {talent[:name] || talent["name"] || "才能"}
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
    <!-- Effect (Completed) -->
      <%= if @is_completed && map_size(@effect) > 0 do %>
        <div class="mt-3 pt-3 border-t border-kin/30">
          <div class="text-xs uppercase tracking-[0.2em] text-kin/70 mb-2">完成恩恵</div>
          <div class="grid grid-cols-3 gap-2 text-center">
            <%= if Map.has_key?(@effect, :forest) or Map.has_key?(@effect, :f) do %>
              <div class="bg-matsu/10 border border-matsu/30 rounded p-2">
                <div class="text-[10px] text-matsu/70 mb-1">F</div>
                <div class="text-sm font-bold text-matsu">
                  {format_effect_value(@effect[:forest] || @effect[:f])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :culture) or Map.has_key?(@effect, :k) do %>
              <div class="bg-sakura/10 border border-sakura/30 rounded p-2">
                <div class="text-[10px] text-sakura/70 mb-1">K</div>
                <div class="text-sm font-bold text-sakura">
                  {format_effect_value(@effect[:culture] || @effect[:k])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :social) or Map.has_key?(@effect, :s) do %>
              <div class="bg-kohaku/10 border border-kohaku/30 rounded p-2">
                <div class="text-[10px] text-kohaku/70 mb-1">S</div>
                <div class="text-sm font-bold text-kohaku">
                  {format_effect_value(@effect[:social] || @effect[:s])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :currency) or Map.has_key?(@effect, :p) do %>
              <div class="bg-kin/10 border border-kin/30 rounded p-2">
                <div class="text-[10px] text-kin/70 mb-1">P</div>
                <div class="text-sm font-bold text-kin">
                  {format_effect_value(@effect[:currency] || @effect[:p])}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp check_unlock_condition(_condition, _assigns) do
    # In real implementation, this would check game state
    # For now, return true for demo
    true
  end

  @doc """
  Renders a modal for contributing talent cards to a project.
  """
  attr :show, :boolean, default: false
  attr :project, :map, default: nil
  attr :available_talents, :list, default: []
  attr :id, :string, default: "project-contribute-modal"
  attr :rest, :global

  def project_contribute_modal(assigns) do
    ~H"""
    <%= if @show && @project do %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
        phx-click="close_project_contribute"
        role="dialog"
        aria-modal="true"
        {@rest}
      >
        <div
          class="resonance-modal-frame relative max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto"
          phx-click-away="close_project_contribute"
        >
          <button
            class="absolute top-4 right-4 w-8 h-8 bg-white/10 text-white rounded-full flex items-center justify-center hover:bg-white/20 transition-colors"
            phx-click="close_project_contribute"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>
          <div class="p-6">
            <h2 class="text-xl font-bold text-[var(--color-landing-pale)] mb-4 tracking-[0.2em]">
              才能カードを捧げる
            </h2>

            <.project_card
              title={@project[:title] || @project["title"] || "プロジェクト"}
              description={@project[:description] || @project["description"] || ""}
              cost={@project[:cost] || @project["cost"] || 0}
              progress={@project[:progress] || @project["progress"] || 0}
              effect={@project[:effect] || @project["effect"] || %{}}
              unlock_condition={@project[:unlock_condition] || @project["unlock_condition"] || %{}}
              is_unlocked={@project[:is_unlocked] || @project["is_unlocked"] || true}
              is_completed={@project[:is_completed] || @project["is_completed"] || false}
              contributed_talents={
                @project[:contributed_talents] || @project["contributed_talents"] || []
              }
              class="mb-4"
            />

            <div class="mt-4">
              <h3 class="text-sm font-bold text-[var(--color-landing-text-primary)] mb-2">
                捧げる才能カードを選択
              </h3>
              <%= if length(@available_talents) == 0 do %>
                <div class="text-center py-6 text-[var(--color-landing-text-secondary)] text-sm bg-white/5 rounded border border-white/10">
                  <p>利用可能な才能カードがありません</p>
                </div>
              <% else %>
                <div class="grid grid-cols-3 sm:grid-cols-4 gap-2 max-h-64 overflow-y-auto scrollbar-thin p-2 bg-white/5 rounded border border-white/10">
                  <%= for talent <- @available_talents do %>
                    <% is_used = talent[:is_used] || talent["is_used"] || false %>
                    <div
                      class={[
                        "relative transition-all duration-300",
                        if(is_used,
                          do: "opacity-40 cursor-not-allowed",
                          else: "cursor-pointer hover:scale-110 hover:z-10"
                        )
                      ]}
                      phx-click={if not is_used, do: "contribute_talent", else: nil}
                      phx-value-talent-id={talent[:id] || talent["id"]}
                      phx-value-project-id={@project[:id] || @project["id"]}
                    >
                      <.talent_card
                        title={talent[:name] || talent["name"] || "才能"}
                        description={talent[:description] || talent["description"]}
                        compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
                        is_used={is_used}
                        class="w-full"
                      />
                      <%= if is_used do %>
                        <div class="absolute inset-0 flex items-center justify-center bg-sumi/20 rounded">
                          <span class="text-[10px] font-bold text-sumi/60">使用済</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="mt-4 flex gap-2">
              <button
                class="flex-1 cta-button cta-solid justify-center tracking-[0.3em]"
                phx-click="confirm_talent_contribution"
              >
                確定
              </button>
              <button
                class="flex-1 cta-button cta-outline justify-center tracking-[0.3em]"
                phx-click="close_project_contribute"
              >
                キャンセル
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a confirmation modal for card usage before execution.
  Shows card details, cost, effects, and preview of parameter changes.
  """
  attr :show, :boolean, default: false
  attr :card, :map, default: nil
  attr :talent_cards, :list, default: []
  attr :current_currency, :integer, default: 0
  attr :current_params, :map, default: %{}
  attr :id, :string, default: "action-confirm-modal"
  attr :rest, :global

  def action_confirm_modal(assigns) do
    ~H"""
    <%= if @show && @card do %>
      <% card_cost = @card[:cost] || @card["cost"] || 0
      card_effect = @card[:effect] || @card["effect"] || %{}
      talent_bonus = min(length(@talent_cards), 2)

      # Calculate final effect with talent bonus
      final_effect = Map.new(card_effect, fn {key, val} -> {key, val + talent_bonus} end)

      # Calculate preview of new parameters
      new_params = calculate_new_params(@current_params, final_effect)

      can_afford = @current_currency >= card_cost %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm"
        phx-click="cancel_action_confirm"
        role="dialog"
        aria-modal="true"
        aria-labelledby="action-confirm-title"
        {@rest}
      >
        <div
          class="resonance-modal-frame relative border-t sm:border border-shu/40 rounded-t-2xl sm:rounded-lg max-w-2xl w-full sm:mx-4 max-h-[85vh] sm:max-h-[90vh] overflow-y-auto"
          phx-click-away="cancel_action_confirm"
        >
          <!-- Drag handle for mobile -->
          <div class="sm:hidden flex justify-center py-2">
            <div class="w-10 h-1 bg-white/30 rounded-full"></div>
          </div>
          <button
            class="absolute top-2 sm:top-4 right-2 sm:right-4 w-8 h-8 bg-white/10 text-white rounded-full flex items-center justify-center hover:bg-white/20 transition-colors"
            phx-click="cancel_action_confirm"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>

          <div class="p-4 sm:p-6">
            <h2
              id="action-confirm-title"
              class="text-lg sm:text-2xl font-bold text-[var(--color-landing-pale)] mb-3 sm:mb-4 tracking-[0.15em] sm:tracking-[0.2em]"
            >
              アクションの確認
            </h2>
            
    <!-- Card Preview -->
            <div class="mb-4">
              <.ofuda_card
                title={@card[:title] || @card["title"] || "カード"}
                description={@card[:description] || @card["description"]}
                cost={card_cost}
                type={@card[:type] || @card["type"] || :action}
                class="mx-auto"
              />
            </div>
            
    <!-- Talent Cards (if any) -->
            <%= if length(@talent_cards) > 0 do %>
              <div class="mb-4 p-3 bg-kin/10 border border-kin/30 rounded">
                <div class="text-xs uppercase tracking-[0.2em] text-kin/70 mb-2">使用する才能カード</div>
                <div class="flex gap-2">
                  <%= for talent <- @talent_cards do %>
                    <div class="px-2 py-1 bg-kin/20 border border-kin/30 rounded text-xs text-kin font-semibold">
                      {talent[:name] || talent["name"] || "才能"}
                    </div>
                  <% end %>
                </div>
                <div class="mt-2 text-xs text-kin/70">
                  ボーナス: +{talent_bonus}
                </div>
              </div>
            <% end %>
            
    <!-- Cost Display -->
            <div class="mb-4 p-3 bg-white/5 border border-white/10 rounded">
              <div class="flex justify-between items-center">
                <span class="text-sm font-semibold text-[var(--color-landing-text-secondary)]">
                  コスト（空環）
                </span>
                <div class="flex items-center gap-2">
                  <span class={[
                    "text-lg font-bold",
                    if(can_afford, do: "text-kin", else: "text-shu")
                  ]}>
                    {card_cost}
                  </span>
                  <span class="text-sm text-[var(--color-landing-text-secondary)]">
                    （現在: {@current_currency}）
                  </span>
                </div>
              </div>
              <%= if not can_afford do %>
                <div class="mt-2 text-xs text-shu">
                  ⚠️ 空環が不足しています
                </div>
              <% end %>
            </div>
            
    <!-- Effect Preview -->
            <div class="mb-4">
              <div class="text-sm font-semibold text-[var(--color-landing-text-secondary)] mb-2">
                効果プレビュー
              </div>
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <%= if Map.has_key?(final_effect, :forest) or Map.has_key?(final_effect, :f) do %>
                  <div class="bg-matsu/10 border border-matsu/30 rounded p-2 text-center">
                    <div class="text-[10px] text-matsu/70 mb-1">F (森)</div>
                    <div class="text-sm font-bold text-matsu">
                      {format_effect_value(final_effect[:forest] || final_effect[:f])}
                    </div>
                  </div>
                <% end %>
                <%= if Map.has_key?(final_effect, :culture) or Map.has_key?(final_effect, :k) do %>
                  <div class="bg-sakura/10 border border-sakura/30 rounded p-2 text-center">
                    <div class="text-[10px] text-sakura/70 mb-1">K (文化)</div>
                    <div class="text-sm font-bold text-sakura">
                      {format_effect_value(final_effect[:culture] || final_effect[:k])}
                    </div>
                  </div>
                <% end %>
                <%= if Map.has_key?(final_effect, :social) or Map.has_key?(final_effect, :s) do %>
                  <div class="bg-kohaku/10 border border-kohaku/30 rounded p-2 text-center">
                    <div class="text-[10px] text-kohaku/70 mb-1">S (社会)</div>
                    <div class="text-sm font-bold text-kohaku">
                      {format_effect_value(final_effect[:social] || final_effect[:s])}
                    </div>
                  </div>
                <% end %>
                <%= if Map.has_key?(final_effect, :currency) or Map.has_key?(final_effect, :p) do %>
                  <div class="bg-kin/10 border border-kin/30 rounded p-2 text-center">
                    <div class="text-[10px] text-kin/70 mb-1">P (空環)</div>
                    <div class="text-sm font-bold text-kin">
                      {format_effect_value(final_effect[:currency] || final_effect[:p])}
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Parameter Change Preview -->
            <%= if map_size(new_params) > 0 do %>
              <div class="mb-4 p-3 bg-white/5 border border-white/10 rounded">
                <div class="text-sm font-semibold text-[var(--color-landing-text-secondary)] mb-2">
                  パラメータ変化のプレビュー
                </div>
                <div class="space-y-1 text-xs">
                  <%= if Map.has_key?(@current_params, :forest) or Map.has_key?(@current_params, :f) do %>
                    <div class="flex justify-between">
                      <span class="text-matsu">F (森)</span>
                      <span class="text-gray-200">
                        {Map.get(@current_params, :forest, Map.get(@current_params, :f, 0))} → {Map.get(
                          new_params,
                          :forest,
                          Map.get(new_params, :f, 0)
                        )}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :culture) or Map.has_key?(@current_params, :k) do %>
                    <div class="flex justify-between">
                      <span class="text-sakura">K (文化)</span>
                      <span class="text-gray-200">
                        {Map.get(@current_params, :culture, Map.get(@current_params, :k, 0))} → {Map.get(
                          new_params,
                          :culture,
                          Map.get(new_params, :k, 0)
                        )}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :social) or Map.has_key?(@current_params, :s) do %>
                    <div class="flex justify-between">
                      <span class="text-kohaku">S (社会)</span>
                      <span class="text-gray-200">
                        {Map.get(@current_params, :social, Map.get(@current_params, :s, 0))} → {Map.get(
                          new_params,
                          :social,
                          Map.get(new_params, :s, 0)
                        )}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :currency) or Map.has_key?(@current_params, :p) do %>
                    <div class="flex justify-between">
                      <span class="text-kin">P (空環)</span>
                      <span class="text-gray-200">
                        {Map.get(@current_params, :currency, Map.get(@current_params, :p, 0))} → {Map.get(
                          new_params,
                          :currency,
                          Map.get(new_params, :p, 0)
                        )}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Action Buttons - Mobile: Sticky bottom, Desktop: Normal flow -->
            <div class="flex flex-col sm:flex-row gap-2 sm:gap-3 mt-4 sm:mt-6 pb-2 sm:pb-0">
              <button
                class={[
                  "flex-1 cta-button justify-center tracking-[0.2em] sm:tracking-[0.3em] py-3 sm:py-2 text-sm sm:text-base",
                  if(can_afford, do: "cta-solid", else: "cta-outline opacity-60 cursor-not-allowed")
                ]}
                phx-click={if can_afford, do: "confirm_action", else: nil}
                disabled={not can_afford}
                aria-label="アクションを実行"
              >
                実行する
              </button>
              <button
                class="flex-1 cta-button cta-outline justify-center tracking-[0.2em] sm:tracking-[0.3em] py-3 sm:py-2 text-sm sm:text-base"
                phx-click="cancel_action_confirm"
                aria-label="キャンセル"
              >
                キャンセル
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp calculate_new_params(current_params, effect) do
    # Normalize effect keys to atoms (handles both atom and string keys)
    normalized_effect =
      Map.new(effect, fn {key, val} ->
        atom_key =
          case key do
            k when is_atom(k) -> k
            "forest" -> :forest
            "f" -> :forest
            "culture" -> :culture
            "k" -> :culture
            "social" -> :social
            "s" -> :social
            "currency" -> :currency
            "p" -> :currency
            k when is_binary(k) -> String.to_existing_atom(k)
          end

        {atom_key, val}
      end)

    Map.merge(current_params, normalized_effect, fn _key, current_val, effect_val ->
      current_val + effect_val
    end)
  end

  @doc """
  Renders a card detail modal for viewing card information.
  Shows detailed card information including description, cost, effects, and usage conditions.
  """
  attr :show, :boolean, default: false
  attr :card, :map, default: nil
  attr :current_currency, :integer, default: 0
  attr :current_params, :map, default: %{}
  attr :id, :string, default: "card-detail-modal"
  attr :rest, :global

  def card_detail_modal(assigns) do
    ~H"""
    <%= if @show && @card do %>
      <% card_cost = @card[:cost] || @card["cost"] || 0
      card_effect = @card[:effect] || @card["effect"] || %{}
      card_type = @card[:type] || @card["type"] || :action
      card_description = @card[:description] || @card["description"] || ""
      card_tags = @card[:tags] || @card["tags"] || []
      can_afford = @current_currency >= card_cost %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in"
        phx-click="close_card_detail"
        role="dialog"
        aria-modal="true"
        aria-labelledby="card-detail-title"
        {@rest}
      >
        <div
          class="resonance-modal-frame relative max-w-md sm:max-w-lg w-full mx-0 sm:mx-4 max-h-[85vh] overflow-y-auto animate-slide-in-up rounded-t-xl sm:rounded-xl"
          phx-click-away="close_card_detail"
          phx-window-keydown={
            JS.push("close_card_detail") |> JS.dispatch("keydown", detail: %{key: "Escape"})
          }
        >
          <button
            class="absolute top-2 sm:top-4 right-2 sm:right-4 w-6 h-6 sm:w-8 sm:h-8 bg-white/10 text-white rounded-full flex items-center justify-center hover:bg-white/20 transition-colors z-10"
            phx-click="close_card_detail"
            aria-label="モーダルを閉じる"
          >
            <span class="text-sm sm:text-lg font-bold">×</span>
          </button>

          <div class="p-3 sm:p-6">
            <h2
              id="card-detail-title"
              class="text-base sm:text-xl font-bold text-[var(--color-landing-pale)] mb-2 sm:mb-4 tracking-[0.1em] sm:tracking-[0.2em]"
            >
              {@card[:title] || @card["title"] || "カード"}
            </h2>
            
    <!-- Card Type Badge & Tags - Inline -->
            <div class="mb-2 sm:mb-4 flex flex-wrap items-center gap-1 sm:gap-2">
              <span class={[
                "px-2 py-0.5 sm:px-3 sm:py-1 rounded-full text-[10px] sm:text-xs font-semibold border",
                case card_type do
                  :action -> "bg-shu/20 text-shu border-shu/40"
                  :reaction -> "bg-matsu/20 text-matsu border-matsu/40"
                  :event -> "bg-white/10 text-white border-white/20"
                  _ -> "bg-white/10 text-white border-white/20"
                end
              ]}>
                {case card_type do
                  :action -> "アクション"
                  :reaction -> "リアクション"
                  :event -> "イベント"
                  _ -> "カード"
                end}
              </span>
              <%= if length(card_tags) > 0 do %>
                <%= for tag <- card_tags do %>
                  <span class="px-1.5 py-0.5 sm:px-2 sm:py-1 bg-kin/10 text-kin border border-kin/30 rounded text-[10px] sm:text-xs">
                    {tag}
                  </span>
                <% end %>
              <% end %>
            </div>
            
    <!-- Description -->
            <%= if card_description != "" do %>
              <div class="mb-2 sm:mb-4 p-2 sm:p-3 bg-white/5 border border-white/10 rounded">
                <p class="text-xs sm:text-sm text-[var(--color-landing-text-primary)] leading-relaxed">
                  {card_description}
                </p>
              </div>
            <% end %>
            
    <!-- Cost Display - Compact -->
            <div class="mb-2 sm:mb-4 p-2 sm:p-3 bg-white/5 border border-white/10 rounded">
              <div class="flex justify-between items-center">
                <span class="text-xs sm:text-sm text-[var(--color-landing-text-secondary)]">
                  コスト
                </span>
                <div class="flex items-center gap-1 sm:gap-2">
                  <span class={[
                    "text-sm sm:text-lg font-bold",
                    if(can_afford, do: "text-kin", else: "text-shu")
                  ]}>
                    φ{card_cost}
                  </span>
                  <span class="text-[10px] sm:text-sm text-[var(--color-landing-text-secondary)]">
                    / φ{@current_currency}
                  </span>
                  <%= if not can_afford do %>
                    <span class="text-[10px] sm:text-xs text-shu">不足</span>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Effects Display -->
            <%= if map_size(card_effect) > 0 do %>
              <div class="mb-4 p-3 bg-white/5 border border-white/10 rounded">
                <div class="text-xs uppercase tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-3">
                  効果
                </div>
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
                  <%= if Map.has_key?(card_effect, :forest) or Map.has_key?(card_effect, :f) do %>
                    <div class="bg-matsu/10 border border-matsu/30 rounded p-2 text-center">
                      <div class="text-[10px] text-matsu/70 mb-1">F (森)</div>
                      <div class="text-sm font-bold text-matsu">
                        {format_effect_value(card_effect[:forest] || card_effect[:f])}
                      </div>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(card_effect, :culture) or Map.has_key?(card_effect, :k) do %>
                    <div class="bg-sakura/10 border border-sakura/30 rounded p-2 text-center">
                      <div class="text-[10px] text-sakura/70 mb-1">K (文化)</div>
                      <div class="text-sm font-bold text-sakura">
                        {format_effect_value(card_effect[:culture] || card_effect[:k])}
                      </div>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(card_effect, :social) or Map.has_key?(card_effect, :s) do %>
                    <div class="bg-kohaku/10 border border-kohaku/30 rounded p-2 text-center">
                      <div class="text-[10px] text-kohaku/70 mb-1">S (社会)</div>
                      <div class="text-sm font-bold text-kohaku">
                        {format_effect_value(card_effect[:social] || card_effect[:s])}
                      </div>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(card_effect, :currency) or Map.has_key?(card_effect, :p) do %>
                    <div class="bg-kin/10 border border-kin/30 rounded p-2 text-center">
                      <div class="text-[10px] text-kin/70 mb-1">P (空環)</div>
                      <div class="text-sm font-bold text-kin">
                        {format_effect_value(card_effect[:currency] || card_effect[:p])}
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
            
    <!-- Usage Conditions - Hidden on mobile for simplicity -->
            <div class="hidden sm:block mb-4 p-3 bg-white/5 border border-white/10 rounded">
              <div class="text-xs uppercase tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-2">
                使用条件
              </div>
              <ul class="space-y-1 text-sm text-[var(--color-landing-text-primary)]">
                <li class="flex items-center gap-2">
                  <%= if can_afford do %>
                    <.icon name="hero-check-circle" class="w-4 h-4 text-matsu" />
                  <% else %>
                    <.icon name="hero-x-circle" class="w-4 h-4 text-shu" />
                  <% end %>
                  <span>空環ポイント: {card_cost}以上</span>
                </li>
                <%= if card_type == :action do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check-circle" class="w-4 h-4 text-matsu" />
                    <span>アクションフェーズで使用可能</span>
                  </li>
                <% end %>
                <%= if card_type == :reaction do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-check-circle" class="w-4 h-4 text-matsu" />
                    <span>リアクションとして使用可能</span>
                  </li>
                <% end %>
              </ul>
            </div>
            
    <!-- Action Buttons - Larger tap targets for mobile -->
            <div class="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-2 sm:gap-4 mt-4 sm:mt-6">
              <%= if can_afford do %>
                <button
                  class="w-full sm:w-auto order-1 sm:order-2 py-3 sm:py-2 px-6 rounded-lg bg-matsu hover:bg-matsu/80 text-white font-bold text-base sm:text-sm tracking-[0.1em] sm:tracking-[0.3em] transition-all active:scale-95"
                  phx-click="use_card_from_detail"
                  phx-value-card-id={@card[:id] || @card["id"]}
                  aria-label="このカードを使用する"
                >
                  🃏 使用する
                </button>
              <% else %>
                <button
                  class="w-full sm:w-auto order-1 sm:order-2 py-3 sm:py-2 px-6 rounded-lg bg-gray-600 cursor-not-allowed opacity-50 text-white font-bold text-base sm:text-sm"
                  disabled
                  aria-label="空環が不足しています"
                >
                  空環不足
                </button>
              <% end %>
              <button
                class="w-full sm:w-auto order-2 sm:order-1 py-2.5 sm:py-2 px-4 rounded-lg border border-white/30 text-white/80 hover:bg-white/10 text-sm transition-all"
                phx-click="close_card_detail"
                aria-label="閉じる"
              >
                閉じる
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders an ending screen based on game result.
  Shows different endings based on Life Index and game status.
  """
  attr :game_status, :atom, required: true, values: [:won, :lost, :playing]
  attr :life_index, :integer, required: true
  attr :final_stats, :map, default: %{}
  attr :turn, :integer, default: 0
  attr :max_turns, :integer, default: 20
  attr :show, :boolean, default: true
  attr :id, :string, default: "ending-screen"
  attr :rest, :global

  def ending_screen(assigns) do
    ending_type =
      determine_ending_type(assigns.game_status, assigns.life_index, assigns.final_stats)

    ending_data = get_ending_data(ending_type)

    assigns =
      assigns
      |> assign(:ending_type, ending_type)
      |> assign(:ending_data, ending_data)

    ~H"""
    <%= if @show && @game_status not in [:playing, "playing", "active"] do %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-md"
        role="dialog"
        aria-modal="true"
        aria-labelledby="ending-title"
        {@rest}
      >
        <div class="resonance-modal-frame relative max-w-4xl w-full sm:mx-4 max-h-[95vh] sm:max-h-[90vh] overflow-y-auto animate-fade-in rounded-t-2xl sm:rounded-lg">
          <!-- Drag handle for mobile -->
          <div class="sm:hidden flex justify-center py-2 sticky top-0 bg-inherit z-10">
            <div class="w-10 h-1 bg-white/30 rounded-full"></div>
          </div>
          <!-- Ending Header -->
          <div class={[
            "p-4 sm:p-8 text-center border-b border-white/10",
            @ending_type == :blessing && "bg-kin/20 border-kin/30",
            @ending_type == :purification && "bg-matsu/20 border-matsu/30",
            @ending_type == :uncertain && "bg-kohaku/20 border-kohaku/30",
            @ending_type == :lament && "bg-shu/20 border-shu/30",
            @ending_type == :instant_loss && "bg-white/10 border-white/20"
          ]}>
            <div class="text-4xl sm:text-6xl mb-2 sm:mb-4 drop-shadow-lg">{@ending_data.icon}</div>
            <h1
              id="ending-title"
              class="text-xl sm:text-3xl md:text-4xl font-bold mb-1 sm:mb-2 tracking-[0.2em] sm:tracking-[0.3em]"
            >
              {@ending_data.title}
            </h1>
            <p class="text-sm sm:text-lg text-[var(--color-landing-text-secondary)] mt-2 sm:mt-4">
              {@ending_data.subtitle}
            </p>
          </div>
          
    <!-- Ending Description -->
          <div class="p-4 sm:p-6 md:p-8">
            <div class="prose prose-invert max-w-none mb-4 sm:mb-6">
              <p class="text-sm sm:text-base leading-relaxed text-[var(--color-landing-text-primary)]">
                {@ending_data.description}
              </p>
            </div>
            
    <!-- Final Statistics - Mobile optimized grid -->
            <div class="mb-4 sm:mb-6 p-3 sm:p-4 bg-white/5 border border-white/10 rounded-lg">
              <h2 class="text-base sm:text-lg font-bold text-[var(--color-landing-pale)] mb-3 sm:mb-4">
                最終結果
              </h2>
              <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
                <div class="text-center p-2 sm:p-0 bg-white/5 sm:bg-transparent rounded">
                  <div class="text-[10px] sm:text-xs uppercase tracking-[0.15em] sm:tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-0.5 sm:mb-1">
                    生命指数
                  </div>
                  <div class="text-xl sm:text-2xl font-bold text-shu">{@life_index}</div>
                </div>
                <div class="text-center p-2 sm:p-0 bg-matsu/10 sm:bg-transparent rounded">
                  <div class="text-[10px] sm:text-xs uppercase tracking-[0.15em] sm:tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-0.5 sm:mb-1">
                    🌲 森
                  </div>
                  <div class="text-lg sm:text-xl font-bold text-matsu">
                    {@final_stats[:forest] || @final_stats["forest"] || 0}
                  </div>
                </div>
                <div class="text-center p-2 sm:p-0 bg-sakura/10 sm:bg-transparent rounded">
                  <div class="text-[10px] sm:text-xs uppercase tracking-[0.15em] sm:tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-0.5 sm:mb-1">
                    🎭 文化
                  </div>
                  <div class="text-lg sm:text-xl font-bold text-sakura">
                    {@final_stats[:culture] || @final_stats["culture"] || 0}
                  </div>
                </div>
                <div class="text-center p-2 sm:p-0 bg-kohaku/10 sm:bg-transparent rounded">
                  <div class="text-[10px] sm:text-xs uppercase tracking-[0.15em] sm:tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-0.5 sm:mb-1">
                    🤝 社会
                  </div>
                  <div class="text-lg sm:text-xl font-bold text-kohaku">
                    {@final_stats[:social] || @final_stats["social"] || 0}
                  </div>
                </div>
              </div>
              <div class="mt-3 sm:mt-4 text-center text-xs sm:text-sm text-[var(--color-landing-text-secondary)]">
                ターン数: {@turn} / {@max_turns}
              </div>
            </div>
            
    <!-- Action Buttons - Mobile: Full width stacked -->
            <div class="flex flex-col gap-2 sm:flex-row sm:gap-3 mt-4 sm:mt-6 pb-4 sm:pb-0">
              <button
                class="flex-1 cta-button cta-solid justify-center tracking-[0.2em] sm:tracking-[0.3em] py-3 sm:py-2"
                phx-click="restart_game"
                aria-label="新しいゲームを開始"
              >
                新しいゲームを開始
              </button>
              <button
                class="flex-1 cta-button cta-outline justify-center tracking-[0.2em] sm:tracking-[0.3em] py-3 sm:py-2"
                phx-click="close_ending"
                aria-label="閉じる"
              >
                閉じる
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp determine_ending_type(status, _life_index, final_stats) when status in [:lost, "failed"] do
    # Check for instant loss (F=0, K=0, or S=0)
    forest = final_stats[:forest] || final_stats["forest"] || 0
    culture = final_stats[:culture] || final_stats["culture"] || 0
    social = final_stats[:social] || final_stats["social"] || 0

    if forest == 0 || culture == 0 || social == 0 do
      :instant_loss
    else
      :lament
    end
  end

  defp determine_ending_type(status, life_index, _final_stats)
       when status in [:won, "completed"] do
    cond do
      life_index >= 40 -> :blessing
      life_index >= 30 -> :purification
      life_index >= 20 -> :uncertain
      true -> :lament
    end
  end

  defp determine_ending_type(_status, life_index, _final_stats) do
    cond do
      life_index >= 40 -> :blessing
      life_index >= 30 -> :purification
      life_index >= 20 -> :uncertain
      true -> :lament
    end
  end

  defp get_ending_data(:blessing) do
    %{
      icon: "🌈",
      title: "神々の祝福",
      subtitle: "The Blessing of the Gods",
      description:
        "20年の歳月を経て、世界は見事に再生しました。森は豊かに茂り、文化は花開き、コミュニティは強く結ばれています。八百万の神々は、あなたたちの努力を祝福し、この世界に永遠の調和をもたらしました。"
    }
  end

  defp get_ending_data(:purification) do
    %{
      icon: "🌿",
      title: "浄化の兆し",
      subtitle: "Signs of Purification",
      description:
        "世界は回復の道を歩み始めています。まだ完全ではありませんが、希望の光が見えています。森、文化、コミュニティは徐々に力を取り戻しつつあります。神々は、この世界の未来に期待を寄せています。"
    }
  end

  defp get_ending_data(:uncertain) do
    %{
      icon: "🌙",
      title: "揺らぎの未来",
      subtitle: "Uncertain Future",
      description:
        "20年が過ぎましたが、世界の未来はまだ定まっていません。いくつかの改善は見られますが、まだ多くの課題が残されています。神々は、この世界がどちらの方向へ向かうのか、見守り続けています。"
    }
  end

  defp get_ending_data(:lament) do
    %{
      icon: "🔥",
      title: "神々の嘆き",
      subtitle: "Lament of the Gods",
      description:
        "20年の歳月を経ても、世界は十分に回復できませんでした。森、文化、コミュニティのいずれかが危機に瀕しています。神々は、この世界の現状を嘆き、さらなる努力を求めています。"
    }
  end

  defp get_ending_data(:instant_loss) do
    %{
      icon: "💀",
      title: "即時ゲームオーバー",
      subtitle: "Instant Game Over",
      description: "森、文化、またはコミュニティのいずれかが完全に失われました。世界は崩壊し、回復の見込みはありません。神々は、この世界を見捨てざるを得ませんでした。"
    }
  end

  @doc """
  Renders a role selection screen for players to choose their role.
  """
  attr :show, :boolean, default: true
  attr :selected_role, :any, default: nil
  attr :available_roles, :list, default: []
  attr :id, :string, default: "role-selection-screen"
  attr :rest, :global

  def role_selection_screen(assigns) do
    roles = [
      %{
        id: :forest_guardian,
        name: "森の守り手",
        name_en: "Forest Guardian",
        focus: "F (Forest) の保護と育成",
        description: "自然環境の豊かさを守り、育む役割。森を大切にし、生態系のバランスを保つ責任があります。",
        detailed_description:
          "森の守り手は、自然環境の保護と育成を専門とします。Forest (F) の値を高めるアクションカードに特に適しており、生態系のバランスを保ちながら、持続可能な成長を実現します。",
        strengths: ["Forest の増加に優れている", "生態系のバランス維持", "自然資源の効率的な活用"],
        color: "matsu",
        icon: "🌲",
        bg_gradient: "from-matsu/20 via-matsu/10 to-transparent"
      },
      %{
        id: :culture_keeper,
        name: "文化の継承者",
        name_en: "Culture Keeper",
        focus: "K (Culture) の継承と発展",
        description: "伝統、芸術、知恵を継承し、発展させる役割。文化の価値を守りながら、新しい表現を生み出します。",
        detailed_description:
          "文化の継承者は、伝統と革新のバランスを取ります。Culture (K) の値を高めるアクションカードに特に適しており、文化の価値を守りながら、新しい表現を生み出します。",
        strengths: ["Culture の増加に優れている", "伝統と革新のバランス", "文化的価値の創造"],
        color: "sakura",
        icon: "🌸",
        bg_gradient: "from-sakura/20 via-sakura/10 to-transparent"
      },
      %{
        id: :community_light,
        name: "コミュニティの灯火",
        name_en: "Community Light",
        focus: "S (Social) の結束と強化",
        description: "人々のつながりを深め、コミュニティを強くする役割。信頼関係を築き、協力の輪を広げます。",
        detailed_description:
          "コミュニティの灯火は、人々のつながりを深め、協力を促進します。Social (S) の値を高めるアクションカードに特に適しており、チーム全体の結束を強化します。",
        strengths: ["Social の増加に優れている", "チーム協力の促進", "信頼関係の構築"],
        color: "kohaku",
        icon: "🕯️",
        bg_gradient: "from-kohaku/20 via-kohaku/10 to-transparent"
      },
      %{
        id: :akasha_engineer,
        name: "空環エンジニア",
        name_en: "Akasha Engineer",
        focus: "P (Akasha) の循環と技術",
        description: "空環マネーの循環を管理し、技術を発展させる役割。経済システムを最適化し、持続可能な循環を実現します。",
        detailed_description:
          "空環エンジニアは、空環マネーの循環を管理し、技術を発展させます。Akasha (P) の値を高めるアクションカードに特に適しており、経済システムを最適化し、持続可能な循環を実現します。",
        strengths: ["Akasha の増加に優れている", "経済システムの最適化", "技術の発展"],
        color: "kin",
        icon: "⚡",
        bg_gradient: "from-kin/20 via-kin/10 to-transparent"
      }
    ]

    assigns = assign(assigns, :roles, roles)

    ~H"""
    <%= if @show do %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="role-selection-title"
        {@rest}
      >
        <div class="relative bg-washi border-4 border-double border-sumi rounded-lg shadow-2xl max-w-6xl w-full max-h-[90vh] overflow-y-auto animate-fade-in">
          <!-- Header -->
          <div class="p-6 md:p-8 text-center border-b-4 border-double border-sumi bg-gradient-to-b from-washi to-washi-dark">
            <h1
              id="role-selection-title"
              class="text-3xl md:text-4xl font-bold text-sumi mb-3"
            >
              役割を選択
            </h1>
            <p class="text-sm md:text-base text-sumi/70 mb-2">あなたの専門性を選んで、チームに貢献しましょう</p>
            <p class="text-xs text-sumi/50">4つの役割から1つを選択してください</p>
          </div>
          
    <!-- Role Cards -->
          <div class="p-6 md:p-8">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
              <%= for role <- @roles do %>
                <% is_selected = @selected_role != nil && @selected_role == role.id

                is_available =
                  Enum.empty?(@available_roles) || Enum.member?(@available_roles, role.id)

                border_color_class =
                  case role.color do
                    "matsu" -> "border-matsu"
                    "sakura" -> "border-sakura"
                    "kohaku" -> "border-kohaku"
                    "kin" -> "border-kin"
                    _ -> "border-sumi"
                  end

                bg_color_class =
                  case role.color do
                    "matsu" -> "bg-matsu/10"
                    "sakura" -> "bg-sakura/10"
                    "kohaku" -> "bg-kohaku/10"
                    "kin" -> "bg-kin/10"
                    _ -> "bg-sumi/10"
                  end

                text_color_class =
                  case role.color do
                    "matsu" -> "text-matsu"
                    "sakura" -> "text-sakura"
                    "kohaku" -> "text-kohaku"
                    "kin" -> "text-kin"
                    _ -> "text-sumi"
                  end %>
                <div
                  class={[
                    "relative p-6 md:p-8 rounded-xl border-4 border-double transition-all duration-500 cursor-pointer overflow-hidden",
                    border_color_class,
                    bg_color_class,
                    if(is_selected,
                      do:
                        "ring-4 ring-shu/50 scale-105 shadow-2xl transform rotate-0 role-card-selected",
                      else: "hover:scale-105 hover:shadow-xl hover:rotate-1"
                    ),
                    if(not is_available, do: "opacity-50 cursor-not-allowed", else: "")
                  ]}
                  phx-click={if is_available, do: "select_role", else: nil}
                  phx-value-role-id={Atom.to_string(role.id)}
                  role="button"
                  aria-label={"役割: #{role.name}"}
                  aria-pressed={is_selected}
                >
                  <!-- Background Gradient -->
                  <div class={["absolute inset-0 bg-gradient-to-br", role.bg_gradient, "opacity-50"]}>
                  </div>
                  
    <!-- Content -->
                  <div class="relative z-10">
                    <%= if is_selected do %>
                      <div class="absolute top-3 right-3 w-10 h-10 bg-shu text-washi rounded-full flex items-center justify-center text-xl font-bold shadow-lg animate-pulse">
                        ✓
                      </div>
                    <% end %>
                    
    <!-- Icon and Title -->
                    <div class="text-center mb-6">
                      <div class={[
                        "text-6xl md:text-7xl mb-3 transform transition-transform duration-300",
                        if(is_selected, do: "role-icon-hover", else: "hover:scale-110")
                      ]}>
                        {role.icon}
                      </div>
                      <h2 class={[
                        "text-2xl md:text-3xl font-bold mb-2",
                        text_color_class
                      ]}>
                        {role.name}
                      </h2>
                      <p class="text-xs md:text-sm text-sumi/60 uppercase tracking-wider mb-4">
                        {role.name_en}
                      </p>
                    </div>
                    
    <!-- Focus -->
                    <div class="mb-4 p-3 rounded-lg bg-washi/80 border border-sumi/20">
                      <div class="text-xs font-semibold text-sumi/80 mb-1 uppercase tracking-wider">
                        焦点
                      </div>
                      <p class={["text-sm font-bold", text_color_class]}>
                        {role.focus}
                      </p>
                    </div>
                    
    <!-- Description -->
                    <div class="mb-4">
                      <div class="text-xs font-semibold text-sumi/80 mb-2 uppercase tracking-wider">
                        概要
                      </div>
                      <p class="text-sm leading-relaxed text-sumi/80">
                        {role.description}
                      </p>
                    </div>
                    
    <!-- Detailed Description (shown when selected) -->
                    <%= if is_selected do %>
                      <div class="mt-4 p-4 rounded-lg bg-washi/90 border-2 border-sumi/30 animate-fade-in">
                        <div class="text-xs font-semibold text-sumi/80 mb-2 uppercase tracking-wider">
                          詳細
                        </div>
                        <p class="text-xs leading-relaxed text-sumi/70 mb-3">
                          {role.detailed_description}
                        </p>
                        <div class="mt-3 pt-3 border-t border-sumi/20">
                          <div class="text-xs font-semibold text-sumi/80 mb-2 uppercase tracking-wider">
                            強み
                          </div>
                          <ul class="space-y-1">
                            <%= for strength <- role.strengths do %>
                              <li class="text-xs text-sumi/70 flex items-start">
                                <span class="text-shu mr-2">•</span>
                                <span>{strength}</span>
                              </li>
                            <% end %>
                          </ul>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
            
    <!-- Action Buttons -->
            <%= if @selected_role do %>
              <div class="mt-8 pt-6 border-t-4 border-double border-sumi">
                <div class="flex flex-col sm:flex-row gap-4 max-w-2xl mx-auto">
                  <button
                    class="flex-1 px-8 py-4 bg-shu text-washi rounded-lg border-4 border-double border-sumi font-bold text-lg hover:bg-shu/90 hover:scale-105 transition-all duration-300 shadow-lg hover:shadow-xl"
                    phx-click="confirm_role_selection"
                    aria-label="役割を確定"
                  >
                    ✓ 役割を確定
                  </button>
                  <button
                    class="flex-1 px-8 py-4 bg-washi text-sumi rounded-lg border-4 border-double border-sumi hover:bg-sumi/5 hover:scale-105 transition-all duration-300 font-semibold text-lg shadow-md hover:shadow-lg"
                    phx-click="cancel_role_selection"
                    aria-label="キャンセル"
                  >
                    キャンセル
                  </button>
                </div>
                <p class="text-center mt-4 text-xs text-sumi/50">
                  選択した役割はゲーム中変更できません
                </p>
              </div>
            <% else %>
              <div class="mt-6 text-center">
                <p class="text-sm text-sumi/60">
                  上記の役割カードをクリックして選択してください
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a player info card showing role and status.
  """
  attr :player_id, :string, required: true
  attr :player_name, :string, required: true
  attr :role, :atom, default: nil
  attr :is_current_player, :boolean, default: false
  attr :is_ready, :boolean, default: false
  attr :is_current_turn, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  def player_info_card(assigns) do
    role_data = get_role_data(assigns.role)

    assigns =
      assigns
      |> assign(:role_data, role_data)

    ~H"""
    <div
      class={[
        "player-info-card p-3 rounded-lg border-2 border-double transition-all duration-300 relative",
        if(@is_current_player, do: "ring-2 ring-shu/50 shadow-md", else: ""),
        if(@is_current_turn, do: "ring-2 ring-kin/50 animate-pulse", else: ""),
        role_color_classes(@role_data),
        @class
      ]}
      role="article"
      aria-label={"プレイヤー: #{@player_name}"}
      {@rest}
    >
      <!-- Current Turn Indicator -->
      <%= if @is_current_turn do %>
        <div class="absolute -top-2 -right-2 w-6 h-6 bg-kin rounded-full border-2 border-sumi flex items-center justify-center shadow-lg z-10">
          <span class="text-xs font-bold text-sumi">⚡</span>
        </div>
      <% end %>
      
    <!-- Header -->
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2 flex-1">
          <%= if @role_data do %>
            <div class="text-2xl flex-shrink-0">{@role_data.icon}</div>
          <% else %>
            <div class="w-8 h-8 rounded-full bg-sumi/20 flex items-center justify-center flex-shrink-0">
              <span class="text-xs text-sumi/60">?</span>
            </div>
          <% end %>
          <div class="flex-1 min-w-0">
            <div class="font-bold text-sumi text-sm truncate">{@player_name}</div>
            <%= if @is_current_player do %>
              <div class="text-xs text-shu font-semibold">（あなた）</div>
            <% end %>
          </div>
        </div>
        <!-- Status Indicators -->
        <div class="flex items-center gap-1.5 flex-shrink-0">
          <%= if @is_ready do %>
            <div
              class="w-3 h-3 bg-matsu rounded-full shadow-sm animate-pulse"
              aria-label="準備完了"
              title="準備完了"
            >
            </div>
          <% else %>
            <div class="w-3 h-3 bg-sumi/30 rounded-full" aria-label="準備中" title="準備中">
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Role Information -->
      <%= if @role_data do %>
        <div class="mt-2 pt-2 border-t border-sumi/20">
          <div class="flex items-center gap-2 mb-1">
            <span class="text-xs font-bold text-sumi">{@role_data.name}</span>
            <span class={[
              "text-[10px] px-2 py-0.5 rounded-full font-semibold",
              role_badge_classes(@role_data)
            ]}>
              {@role_data.focus}
            </span>
          </div>
        </div>
      <% else %>
        <div class="mt-2 pt-2 border-t border-sumi/20">
          <div class="text-[10px] text-sumi/50 italic">役割未選択</div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_role_data(:forest_guardian) do
    %{name: "森の守り手", focus: "F (Forest) の保護と育成", color: "matsu", icon: "🌲"}
  end

  defp get_role_data(:culture_keeper) do
    %{name: "文化の継承者", focus: "K (Culture) の継承と発展", color: "sakura", icon: "🌸"}
  end

  defp get_role_data(:community_light) do
    %{name: "コミュニティの灯火", focus: "S (Social) の結束と強化", color: "kohaku", icon: "🕯️"}
  end

  defp get_role_data(:akasha_engineer) do
    %{name: "空環エンジニア", focus: "P (Akasha) の循環と技術", color: "kin", icon: "⚡"}
  end

  defp get_role_data(_), do: nil

  defp role_color_classes(nil), do: "border-white/10 bg-white/5"

  defp role_color_classes(%{color: color}) do
    case color do
      "matsu" -> "border-matsu bg-matsu/10"
      "sakura" -> "border-sakura bg-sakura/10"
      "kohaku" -> "border-kohaku bg-kohaku/10"
      "kin" -> "border-kin bg-kin/10"
      _ -> "border-white/10 bg-white/5"
    end
  end

  defp role_badge_classes(nil), do: "bg-white/10 text-white border border-white/20"

  defp role_badge_classes(%{color: color}) do
    case color do
      "matsu" -> "bg-matsu/20 text-matsu border border-matsu/30"
      "sakura" -> "bg-sakura/20 text-sakura border border-sakura/30"
      "kohaku" -> "bg-kohaku/20 text-kohaku border border-kohaku/30"
      "kin" -> "bg-kin/20 text-kin border border-kin/30"
      _ -> "bg-white/10 text-white border border-white/20"
    end
  end

  defp project_state_classes(%{is_completed: true}), do: "project-card--completed"
  defp project_state_classes(%{is_unlocked: true}), do: "project-card--active"
  defp project_state_classes(_), do: "project-card--locked"

  @doc """
  Renders a modal displaying demurrage (減衰) information.
  Shows the currency before and after demurrage with animation.
  """
  attr :show, :boolean, default: false
  attr :previous_currency, :integer, default: 0
  attr :current_currency, :integer, default: 0
  attr :demurrage_amount, :integer, default: 0
  attr :id, :string, default: "demurrage-modal"
  attr :rest, :global

  def demurrage_modal(assigns) do
    demurrage_percentage =
      if assigns.previous_currency > 0,
        do: abs(assigns.demurrage_amount) / assigns.previous_currency * 100,
        else: 0.0

    assigns = assign(assigns, :demurrage_percentage, Float.round(demurrage_percentage, 1))

    ~H"""
    <%= if @show do %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in"
        phx-click="close_demurrage"
        role="dialog"
        aria-modal="true"
        aria-labelledby="demurrage-modal-title"
        {@rest}
      >
        <div
          class="resonance-modal-frame relative border border-kin/40 max-w-md w-full mx-4 animate-slide-in-up"
          phx-click-away="close_demurrage"
        >
          <button
            class="absolute top-4 right-4 w-8 h-8 bg-white/10 text-white rounded-full flex items-center justify-center hover:bg-white/20 transition-colors z-10"
            phx-click="close_demurrage"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>

          <div class="p-6 md:p-8">
            <!-- Header -->
            <div class="text-center mb-6">
              <div class="text-4xl mb-3 animate-bounce">💸</div>
              <h2
                id="demurrage-modal-title"
                class="text-2xl md:text-3xl font-bold text-[var(--color-landing-pale)] mb-2 tracking-[0.3em]"
              >
                減衰フェーズ
              </h2>
              <p class="text-sm text-[var(--color-landing-text-secondary)]">
                空環ポイントが減衰しました
              </p>
            </div>
            
    <!-- Currency Display with Animation -->
            <div class="space-y-4 mb-6">
              <!-- Before -->
              <div class="bg-kin/10 border border-kin/30 rounded-lg p-4 text-center">
                <div class="text-xs uppercase tracking-[0.3em] text-kin/70 mb-2">減衰前</div>
                <div class="text-3xl md:text-4xl font-bold text-kin" id="demurrage-before">
                  {@previous_currency}
                </div>
                <div class="text-xs text-kin/60 mt-1">空環ポイント</div>
              </div>
              
    <!-- Arrow -->
              <div class="flex items-center justify-center">
                <div class="w-12 h-0.5 bg-kin/50 relative">
                  <div class="absolute right-0 top-1/2 -translate-y-1/2 w-0 h-0 border-l-8 border-l-kin/50 border-t-4 border-t-transparent border-b-4 border-b-transparent">
                  </div>
                </div>
                <div class="mx-3 text-2xl text-shu animate-pulse">↓</div>
                <div class="w-12 h-0.5 bg-kin/50 relative">
                  <div class="absolute right-0 top-1/2 -translate-y-1/2 w-0 h-0 border-l-8 border-l-kin/50 border-t-4 border-t-transparent border-b-4 border-b-transparent">
                  </div>
                </div>
              </div>
              
    <!-- After -->
              <div class="bg-shu/10 border border-shu/30 rounded-lg p-4 text-center animate-pulse">
                <div class="text-xs uppercase tracking-[0.3em] text-shu/70 mb-2">減衰後</div>
                <div class="text-3xl md:text-4xl font-bold text-shu" id="demurrage-after">
                  {@current_currency}
                </div>
                <div class="text-xs text-shu/60 mt-1">空環ポイント</div>
              </div>
            </div>
            
    <!-- Demurrage Amount -->
            <div class="bg-white/5 border border-white/10 rounded-lg p-4 mb-6">
              <div class="flex justify-between items-center">
                <span class="text-sm font-semibold text-[var(--color-landing-text-secondary)]">
                  減衰量
                </span>
                <div class="flex items-center gap-2">
                  <span class="text-xl font-bold text-shu">
                    {if @demurrage_amount < 0,
                      do: "#{@demurrage_amount}",
                      else: "-#{@demurrage_amount}"}
                  </span>
                  <span class="text-sm text-sumi/60">
                    ({@demurrage_percentage}%)
                  </span>
                </div>
              </div>
            </div>
            
    <!-- Explanation -->
            <div class="bg-white/5 border border-white/10 rounded-lg p-4 mb-6">
              <div class="text-xs uppercase tracking-[0.2em] text-[var(--color-landing-text-secondary)] mb-2">
                減衰について
              </div>
              <p class="text-sm text-[var(--color-landing-text-primary)] leading-relaxed">
                空環マネーは貯め込むと価値が減ります。積極的に使って循環させることが重要です。
              </p>
            </div>
            
    <!-- Close Button -->
            <button
              class="w-full cta-button cta-solid justify-center tracking-[0.3em]"
              phx-click="close_demurrage"
              aria-label="閉じる"
            >
              了解
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a toast notification following the TRDS (Torii Resonance Design System) style.
  """
  attr :kind, :atom, default: :info, values: [:success, :error, :info, :warning]
  attr :message, :string, required: true
  attr :id, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  def toast(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "fixed top-4 right-4 z-50 min-w-[300px] max-w-md p-4 rounded-lg border animate-slide-in-right shadow-[0_15px_40px_rgba(0,0,0,0.35)] bg-[rgba(15,20,25,0.9)] text-[var(--color-landing-text-primary)] backdrop-blur-lg",
        @kind == :success && "border-matsu/50",
        @kind == :error && "border-shu/50",
        @kind == :info && "border-[var(--color-landing-gold)]/40",
        @kind == :warning && "border-kohaku/50",
        @class
      ]}
      role="alert"
      aria-live="assertive"
      {@rest}
    >
      <div class="flex items-start gap-3">
        <div class={[
          "flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold",
          @kind == :success && "bg-matsu/30 text-matsu",
          @kind == :error && "bg-shu/30 text-shu",
          @kind == :info && "bg-white/10 text-[var(--color-landing-pale)]",
          @kind == :warning && "bg-kohaku/30 text-kohaku"
        ]}>
          {if @kind == :success, do: "✓", else: if(@kind == :error, do: "✕", else: "ℹ")}
        </div>
        <p class="flex-1 text-sm leading-relaxed">{@message}</p>
      </div>
    </div>
    """
  end

  defp join_class(classes) do
    classes
    |> List.flatten()
    |> Enum.filter(&(&1 && &1 != "" && &1 != false))
    |> Enum.join(" ")
  end

  @doc """
  Renders a jaki (邪気) track showing the current jaki level.
  """
  attr :jaki, :integer, required: true
  attr :class, :string, default: nil

  def jaki_track(assigns) do
    ~H"""
    <div class={["jaki-track flex flex-col items-center", @class]}>
      <div class="text-xs font-bold text-sumi/70 mb-1">邪気</div>
      <div class="flex items-center gap-0.5">
        <%= for i <- 0..8 do %>
          <div
            class={[
              "w-4 h-4 sm:w-5 sm:h-5 rounded-sm flex items-center justify-center text-[10px] font-bold transition-all",
              if(i <= @jaki,
                do: jaki_color(i),
                else: "bg-sumi/10 text-sumi/30"
              )
            ]}
            title={"邪気レベル #{i}"}
          >
            <%= if i == @jaki do %>
              <span class="animate-pulse">{i}</span>
            <% else %>
              {i}
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="text-[10px] text-sumi/50 mt-1">
        人代: {hitoyo_count(@jaki)}枚
      </div>
    </div>
    """
  end

  defp jaki_color(level) when level <= 2, do: "bg-matsu/30 text-matsu"
  defp jaki_color(level) when level <= 5, do: "bg-kohaku/40 text-kohaku"
  defp jaki_color(_level), do: "bg-shu/40 text-shu"

  defp hitoyo_count(jaki) when jaki <= 2, do: 1
  defp hitoyo_count(jaki) when jaki <= 5, do: 2
  defp hitoyo_count(_jaki), do: 3

  @doc """
  Renders a kuukan (空環) display for a player.
  """
  attr :kuukan, :integer, required: true
  attr :class, :string, default: nil
  attr :compact, :boolean, default: false

  def kuukan_display(assigns) do
    ~H"""
    <div class={[
      "kuukan-display flex items-center gap-1",
      if(@compact, do: "text-xs", else: "text-sm"),
      @class
    ]}>
      <span class="text-kohaku font-bold">P</span>
      <div class="flex items-center gap-0.5">
        <%= for i <- 1..10 do %>
          <div
            class={[
              if(@compact, do: "w-2 h-2", else: "w-3 h-3"),
              "rounded-full transition-all",
              if(i <= @kuukan,
                do: kuukan_color(@kuukan, i),
                else: "bg-sumi/10"
              )
            ]}
            title={"空環 #{i}"}
          />
        <% end %>
      </div>
      <span class={["font-mono font-bold", if(@kuukan >= 5, do: "text-shu", else: "text-kohaku")]}>
        {@kuukan}
      </span>
      <%= if @kuukan >= 5 do %>
        <span class="text-[10px] text-shu animate-pulse">還流必須</span>
      <% end %>
    </div>
    """
  end

  defp kuukan_color(total, _i) when total >= 5, do: "bg-shu/60"
  defp kuukan_color(_total, _i), do: "bg-kohaku/50"

  @doc """
  Renders a musuhi chip display.
  """
  attr :received, :integer, default: 0
  attr :available, :integer, default: 0
  attr :class, :string, default: nil

  def musuhi_display(assigns) do
    ~H"""
    <div class={["musuhi-display flex items-center gap-2 text-xs", @class]}>
      <div class="flex items-center gap-1">
        <span class="text-pink-500">💝</span>
        <span class="text-sumi/70">受: </span>
        <span class={["font-bold", if(@received >= 2, do: "text-pink-500", else: "text-sumi")]}>
          {@received}
        </span>
      </div>
      <div class="flex items-center gap-1">
        <span class="text-sumi/70">渡: </span>
        <span class="font-bold text-sumi">{@available}</span>
      </div>
      <%= if @received >= 2 do %>
        <span class="text-[10px] text-pink-500 animate-pulse">才能獲得可!</span>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a hitoyo card (人代カード).
  """
  attr :card, :map, required: true
  attr :class, :string, default: nil

  def hitoyo_card(assigns) do
    ~H"""
    <div class={[
      "hitoyo-card p-3 bg-gradient-to-br from-sumi/90 to-sumi/70 text-washi rounded-lg shadow-lg border border-sumi/50",
      @class
    ]}>
      <div class="flex items-start justify-between mb-2">
        <h4 class="font-bold text-sm text-shu">{@card.name}</h4>
        <span class={[
          "text-[10px] px-1.5 py-0.5 rounded",
          if(@card.timing == :instant, do: "bg-shu/30 text-shu", else: "bg-kohaku/30 text-kohaku")
        ]}>
          {if @card.timing == :instant, do: "即時", else: "遅延"}
        </span>
      </div>
      <p class="text-xs text-washi/80 mb-2">{@card.description}</p>
      <%= if @card.flavor do %>
        <p class="text-[10px] text-washi/50 italic border-t border-washi/20 pt-1">{@card.flavor}</p>
      <% end %>
      <div class="flex gap-2 mt-2">
        <%= for {key, val} <- @card.effect || %{} do %>
          <span class={[
            "text-[10px] px-1.5 py-0.5 rounded",
            effect_color(key, val)
          ]}>
            {effect_label(key)}: {if val > 0, do: "+#{val}", else: val}
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp effect_label(:forest), do: "F"
  defp effect_label(:culture), do: "K"
  defp effect_label(:social), do: "S"
  defp effect_label(:jaki), do: "邪気"
  defp effect_label(:currency), do: "P"
  defp effect_label(key), do: to_string(key)

  defp effect_color(:jaki, val) when val > 0, do: "bg-shu/30 text-shu"
  defp effect_color(:jaki, _val), do: "bg-matsu/30 text-matsu"
  defp effect_color(_key, val) when val < 0, do: "bg-shu/30 text-shu"
  defp effect_color(_key, _val), do: "bg-matsu/30 text-matsu"
end
