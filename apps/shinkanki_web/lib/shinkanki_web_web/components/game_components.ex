defmodule ShinkankiWebWeb.GameComponents do
  use Phoenix.Component

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
        "relative w-24 h-36 bg-washi border-2 border-sumi shadow-md flex flex-col items-center p-2 transition-all duration-300 select-none",
        if(@disabled,
          do: "cursor-not-allowed opacity-50",
          else:
            "cursor-pointer hover:-translate-y-2 hover:shadow-xl hover:border-shu/50 active:scale-95"
        ),
        "before:content-[''] before:absolute before:top-1 before:w-2 before:h-2 before:bg-sumi/10 before:rounded-full",
        "focus:outline-none focus:ring-2 focus:ring-shu/50 focus:ring-offset-2",
        @class
      ]}
      role="button"
      tabindex={if @disabled, do: "-1", else: "0"}
      aria-label={"カード: #{@title}, コスト: #{@cost}"}
      aria-disabled={@disabled}
      {@rest}
    >
      <div class="w-full border-b border-sumi pb-1 text-center">
        <span class="writing-mode-vertical text-xs font-serif font-bold text-sumi tracking-widest">
          {@title}
        </span>
      </div>

      <div class="flex-1 flex items-center justify-center py-2">
        <div class={[
          "w-12 h-12 rounded-full border border-sumi flex items-center justify-center text-2xl font-serif",
          @type == :action && "text-shu bg-shu/5",
          @type == :reaction && "text-matsu bg-matsu/5",
          @type == :event && "text-sumi bg-sumi/5"
        ]}>
          {String.first(@title)}
        </div>
      </div>

      <div class="w-full border-t border-sumi pt-1 flex justify-between items-end">
        <span class="text-[10px] text-sumi/60 font-mono">Cost:{@cost}</span>
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
        "rounded-full border-4 border-double flex items-center justify-center transition-all duration-200 shadow-sm",
        "hover:shadow-md hover:scale-110",
        "active:scale-90 active:shadow-inner",
        "focus:outline-none focus:ring-2 focus:ring-offset-2",
        @color == "shu" && "border-shu text-shu bg-washi hover:bg-shu/5 focus:ring-shu/50",
        @color == "sumi" && "border-sumi text-sumi bg-washi hover:bg-sumi/5 focus:ring-sumi/50",
        @color == "matsu" && "border-matsu text-matsu bg-washi hover:bg-matsu/5 focus:ring-matsu/50",
        @class
      ]}
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
  attr :current_phase, :atom, required: true, values: [:event, :discussion, :action, :demurrage, :life_update, :judgment]
  attr :class, :string, default: nil
  attr :rest, :global

  def phase_indicator(assigns) do
    phases = [
      {:event, "イベント", "イベントカードを1枚めくり、効果を適用する"},
      {:discussion, "相談", "プレイヤー全員で方針を相談する"},
      {:action, "アクション", "アクションカードを選択し、実行する"},
      {:demurrage, "減衰", "空環ポイント(P)の減衰処理"},
      {:life_update, "生命更新", "L = F + K + S を再計算"},
      {:judgment, "判定", "ゲームオーバー条件のチェック"}
    ]

    assigns = assign(assigns, :phases, phases)

    ~H"""
    <div class={["phase-indicator", @class]} role="region" aria-label="ゲームフェーズ" {@rest}>
      <div class="flex items-center justify-center gap-1 sm:gap-2 mb-2 flex-wrap">
        <%= for {{phase, name, _desc}, index} <- Enum.with_index(@phases) do %>
          <div class="flex flex-col items-center gap-1">
            <div
              class={[
                "w-8 h-8 sm:w-10 sm:h-10 rounded-full border-2 flex items-center justify-center text-xs sm:text-sm font-bold transition-all duration-300",
                if(phase == @current_phase, do: "border-shu bg-shu/10 text-shu scale-110 shadow-md", else: "border-sumi/30 bg-washi text-sumi/50 scale-100")
              ]}
              aria-current={if(phase == @current_phase, do: "step", else: "false")}
              aria-label={"フェーズ #{index + 1}: #{name}"}
            >
              {index + 1}
            </div>
            <span class={[
              "text-[9px] sm:text-[10px] font-semibold uppercase tracking-[0.2em] text-center",
              if(phase == @current_phase, do: "text-shu", else: "text-sumi/40")
            ]}>
              {name}
            </span>
            <%= if index < length(@phases) - 1 do %>
              <div class={[
                "hidden sm:block w-4 sm:w-8 h-0.5 mt-2 transition-all duration-300",
                if(phase == @current_phase, do: "bg-shu/50", else: "bg-sumi/20")
              ]} aria-hidden="true"></div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="text-center">
        <%= for {phase, name, desc} <- @phases do %>
          <%= if phase == @current_phase do %>
            <div class="px-4 py-2 bg-washi border border-sumi/20 rounded-lg shadow-sm">
              <div class="text-sm sm:text-base font-bold text-shu mb-1">{name}フェーズ</div>
              <div class="text-xs sm:text-sm text-sumi/70 leading-relaxed">{desc}</div>
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
  attr :category, :atom, default: :neutral, values: [:disaster, :festival, :blessing, :temptation, :neutral]
  attr :class, :string, default: nil
  attr :rest, :global

  def event_card(assigns) do
    category_colors = %{
      disaster: "border-shu bg-shu/5",
      festival: "border-matsu bg-matsu/5",
      blessing: "border-kin bg-kin/5",
      temptation: "border-kohaku bg-kohaku/5",
      neutral: "border-sumi bg-sumi/5"
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
        "relative w-full max-w-md mx-auto bg-washi border-4 border-double shadow-xl rounded-lg p-6 transition-all duration-300",
        @border_color,
        @class
      ]}
      role="article"
      aria-label={"イベントカード: #{@title}"}
      {@rest}
    >
      <!-- Header -->
      <div class="flex items-center justify-between mb-4 pb-3 border-b-2 border-sumi/30">
        <div class="flex items-center gap-3">
          <div class="text-3xl">{@icon}</div>
          <h3 class="text-xl font-bold text-sumi writing-mode-vertical">
            {@title}
          </h3>
        </div>
        <div class="text-xs uppercase tracking-[0.3em] text-sumi/50">
          イベント
        </div>
      </div>

      <!-- Description -->
      <div class="mb-4">
        <p class="text-sm leading-relaxed text-sumi">{@description}</p>
      </div>

      <!-- Effect Display -->
      <%= if map_size(@effect) > 0 do %>
        <div class="mt-4 pt-4 border-t border-sumi/20">
          <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-2">効果</div>
          <div class="grid grid-cols-3 gap-2 text-center">
            <%= if Map.has_key?(@effect, :forest) or Map.has_key?(@effect, :f) do %>
              <div class="bg-matsu/10 border border-matsu/30 rounded p-2">
                <div class="text-[10px] text-matsu/70 mb-1">F (森)</div>
                <div class="text-sm font-bold text-matsu">
                  {format_effect_value(@effect[:forest] || @effect[:f])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :culture) or Map.has_key?(@effect, :k) do %>
              <div class="bg-sakura/10 border border-sakura/30 rounded p-2">
                <div class="text-[10px] text-sakura/70 mb-1">K (文化)</div>
                <div class="text-sm font-bold text-sakura">
                  {format_effect_value(@effect[:culture] || @effect[:k])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :social) or Map.has_key?(@effect, :s) do %>
              <div class="bg-kohaku/10 border border-kohaku/30 rounded p-2">
                <div class="text-[10px] text-kohaku/70 mb-1">S (社会)</div>
                <div class="text-sm font-bold text-kohaku">
                  {format_effect_value(@effect[:social] || @effect[:s])}
                </div>
              </div>
            <% end %>
            <%= if Map.has_key?(@effect, :currency) or Map.has_key?(@effect, :p) do %>
              <div class="bg-kin/10 border border-kin/30 rounded p-2">
                <div class="text-[10px] text-kin/70 mb-1">P (空環)</div>
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
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
        phx-click="close_event_modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="event-modal-title"
        {@rest}
      >
        <div
          class="relative bg-washi border-4 border-double border-sumi rounded-lg shadow-2xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto"
          phx-click-away="close_event_modal"
          phx-window-keydown={JS.push("close_event_modal") |> JS.dispatch("keydown", detail: %{key: "Escape"})}
        >
          <button
            class="absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30 transition-colors"
            phx-click="close_event_modal"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>
          <div class="p-6">
            <.event_card
              title={@event[:title] || @event["title"] || "イベント"}
              description={@event[:description] || @event["description"] || ""}
              effect={@event[:effect] || @event["effect"] || %{}}
              category={@event[:category] || @event["category"] || :neutral}
            />
          </div>
        </div>
      </div>
    <% end %>
    """
  end

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
        "relative w-16 h-20 bg-kin/10 border-2 border-kin shadow-sm flex flex-col items-center p-1.5 transition-all duration-300 select-none",
        if(@is_used,
          do: "cursor-not-allowed opacity-40",
          else:
            if(@is_selected,
              do: "cursor-pointer ring-2 ring-kin border-kin scale-110 z-20",
              else: "cursor-pointer hover:-translate-y-1 hover:shadow-md hover:border-kin/70 active:scale-95"
            )
        ),
        "before:content-[''] before:absolute before:top-0.5 before:w-1.5 before:h-1.5 before:bg-kin/20 before:rounded-full",
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
        <div class="absolute -top-2 -right-2 z-10 flex flex-col gap-1">
          <%= for {talent, index} <- Enum.with_index(Enum.take(@talent_cards, 2)) do %>
            <div
              class={[
                "relative",
                if(index > 0, do: "-mt-3", else: "")
              ]}
            >
              <.talent_card
                title={talent[:title] || talent["title"] || "才能"}
                description={talent[:description] || talent["description"]}
                compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
                class="w-12 h-14 text-[8px]"
              />
              <%= if index == 0 && @talent_count > 1 do %>
                <div class="absolute -bottom-1 -right-1 w-3 h-3 bg-kin rounded-full border border-sumi flex items-center justify-center text-[6px] font-bold text-sumi">
                  +{@talent_count - 1}
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Bonus Indicator -->
        <div class="absolute -bottom-1 -left-1 w-6 h-6 bg-kin rounded-full border-2 border-sumi flex items-center justify-center text-xs font-bold text-sumi shadow-md">
          +{@bonus}
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
      class="bg-washi border-2 border-kin rounded-lg p-4 shadow-lg max-w-md"
      role="dialog"
      aria-label="才能カード選択"
      {@rest}
    >
      <div class="mb-3">
        <h3 class="text-sm font-bold text-sumi mb-1">才能カードを選択（最大{@max_selection}枚）</h3>
        <p class="text-xs text-sumi/60">アクションカードに重ねて効果を強化できます</p>
      </div>

      <%= if length(@compatible_talents) == 0 do %>
        <div class="text-center py-4 text-sumi/50 text-sm">
          互換性のある才能カードがありません
        </div>
      <% else %>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-48 overflow-y-auto scrollbar-thin">
          <%= for talent <- @compatible_talents do %>
            <%
              talent_id = talent[:id] || talent["id"]
              is_selected = Enum.member?(@selected_talent_ids, talent_id)
              can_select = length(@selected_talent_ids) < @max_selection || is_selected
            %>
            <.talent_card
              title={talent[:name] || talent["name"] || "才能"}
              description={talent[:description] || talent["description"]}
              compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
              is_selected={is_selected}
              class={[
                "w-full",
                if(not can_select, do: "opacity-50 cursor-not-allowed", else: "")
              ]}
              phx-click={if can_select, do: "toggle_talent", else: nil}
              phx-value-talent-id={talent_id}
            />
          <% end %>
        </div>
      <% end %>

      <%= if length(@selected_talent_ids) > 0 do %>
        <div class="mt-3 pt-3 border-t border-kin/20">
          <div class="text-xs text-sumi/70 mb-2">
            選択中: {length(@selected_talent_ids)} / {@max_selection}
          </div>
          <div class="flex gap-2">
            <button
              class="flex-1 bg-kin text-sumi px-3 py-2 rounded border border-sumi hover:bg-kin/80 transition-colors text-sm font-semibold"
              phx-click="confirm_talent_selection"
            >
              確定
            </button>
            <button
              class="flex-1 bg-washi text-sumi px-3 py-2 rounded border border-sumi hover:bg-sumi/5 transition-colors text-sm"
              phx-click="cancel_talent_selection"
            >
              キャンセル
            </button>
          </div>
        </div>
      <% end %>
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
    progress_percentage = if assigns.cost > 0, do: min(100, trunc(assigns.progress / assigns.cost * 100)), else: 0
    is_unlockable = check_unlock_condition(assigns.unlock_condition, assigns)

    assigns =
      assigns
      |> assign(:progress_percentage, progress_percentage)
      |> assign(:is_unlockable, is_unlockable)

    ~H"""
    <div
      class={[
        "relative w-full max-w-sm bg-washi border-4 border-double shadow-lg rounded-lg p-4 transition-all duration-300",
        if(@is_completed,
          do: "border-kin bg-kin/5",
          else: if(@is_unlocked, do: "border-matsu bg-matsu/5", else: "border-sumi/30 bg-sumi/5 opacity-60")
        ),
        @class
      ]}
      role="article"
      aria-label={"プロジェクトカード: #{@title}"}
      {@rest}
    >
      <!-- Header -->
      <div class="flex items-center justify-between mb-3 pb-2 border-b-2 border-sumi/30">
        <div class="flex items-center gap-2">
          <div class="text-2xl">
            {if @is_completed, do: "✨", else: if(@is_unlocked, do: "🏗️", else: "🔒")}
          </div>
          <h3 class="text-lg font-bold text-sumi writing-mode-vertical">
            {@title}
          </h3>
        </div>
        <div class="text-xs uppercase tracking-[0.3em] text-sumi/50">
          プロジェクト
        </div>
      </div>

      <!-- Description -->
      <div class="mb-3">
        <p class="text-sm leading-relaxed text-sumi">{@description}</p>
      </div>

      <!-- Unlock Condition -->
      <%= if not @is_unlocked && map_size(@unlock_condition) > 0 do %>
        <div class="mb-3 p-2 bg-sumi/10 border border-sumi/20 rounded">
          <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-1">アンロック条件</div>
          <div class="flex gap-2 text-xs">
            <%= if Map.has_key?(@unlock_condition, :forest) or Map.has_key?(@unlock_condition, :f) do %>
              <span class="text-matsu">F: {Map.get(@unlock_condition, :forest, Map.get(@unlock_condition, :f, 0))}</span>
            <% end %>
            <%= if Map.has_key?(@unlock_condition, :culture) or Map.has_key?(@unlock_condition, :k) do %>
              <span class="text-sakura">K: {Map.get(@unlock_condition, :culture, Map.get(@unlock_condition, :k, 0))}</span>
            <% end %>
            <%= if Map.has_key?(@unlock_condition, :social) or Map.has_key?(@unlock_condition, :s) do %>
              <span class="text-kohaku">S: {Map.get(@unlock_condition, :social, Map.get(@unlock_condition, :s, 0))}</span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Progress Bar -->
      <%= if @is_unlocked && not @is_completed do %>
        <div class="mb-3">
          <div class="flex justify-between items-center mb-1">
            <span class="text-xs text-sumi/70">進捗</span>
            <span class="text-xs font-semibold text-sumi">
              {@progress} / {@cost}
            </span>
          </div>
          <div class="w-full h-3 bg-sumi/10 rounded-full overflow-hidden border border-sumi/20">
            <div
              class="h-full bg-matsu transition-all duration-500"
              style={"width: #{@progress_percentage}%"}
              role="progressbar"
              aria-valuenow={@progress}
              aria-valuemin="0"
              aria-valuemax={@cost}
            >
            </div>
          </div>
        </div>
      <% end %>

      <!-- Contributed Talents -->
      <%= if length(@contributed_talents) > 0 do %>
        <div class="mb-3 pt-2 border-t border-sumi/20">
          <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-2">捧げられた才能</div>
          <div class="flex flex-wrap gap-1">
            <%= for talent <- @contributed_talents do %>
              <div class="px-2 py-1 bg-kin/20 border border-kin/30 rounded text-[10px] text-kin font-semibold">
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
          class="relative bg-washi border-4 border-double border-matsu rounded-lg shadow-2xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto"
          phx-click-away="close_project_contribute"
        >
          <button
            class="absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30 transition-colors"
            phx-click="close_project_contribute"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>
          <div class="p-6">
            <h2 class="text-xl font-bold text-sumi mb-4">才能カードを捧げる</h2>

            <.project_card
              title={@project[:title] || @project["title"] || "プロジェクト"}
              description={@project[:description] || @project["description"] || ""}
              cost={@project[:cost] || @project["cost"] || 0}
              progress={@project[:progress] || @project["progress"] || 0}
              effect={@project[:effect] || @project["effect"] || %{}}
              unlock_condition={@project[:unlock_condition] || @project["unlock_condition"] || %{}}
              is_unlocked={@project[:is_unlocked] || @project["is_unlocked"] || true}
              is_completed={@project[:is_completed] || @project["is_completed"] || false}
              contributed_talents={@project[:contributed_talents] || @project["contributed_talents"] || []}
              class="mb-4"
            />

            <div class="mt-4">
              <h3 class="text-sm font-bold text-sumi mb-2">捧げる才能カードを選択</h3>
              <div class="grid grid-cols-3 sm:grid-cols-4 gap-2 max-h-64 overflow-y-auto scrollbar-thin">
                <%= for talent <- @available_talents do %>
                  <%
                    is_used = talent[:is_used] || talent["is_used"] || false
                  %>
                  <.talent_card
                    title={talent[:name] || talent["name"] || "才能"}
                    description={talent[:description] || talent["description"]}
                    compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
                    is_used={is_used}
                    class="w-full"
                    phx-click={if not is_used, do: "contribute_talent", else: nil}
                    phx-value-talent-id={talent[:id] || talent["id"]}
                    phx-value-project-id={@project[:id] || @project["id"]}
                  />
                <% end %>
              </div>
            </div>

            <div class="mt-4 flex gap-2">
              <button
                class="flex-1 bg-matsu text-washi px-4 py-2 rounded border border-sumi hover:bg-matsu/80 transition-colors text-sm font-semibold"
                phx-click="confirm_talent_contribution"
              >
                確定
              </button>
              <button
                class="flex-1 bg-washi text-sumi px-4 py-2 rounded border border-sumi hover:bg-sumi/5 transition-colors text-sm"
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
      <%
        card_cost = @card[:cost] || @card["cost"] || 0
        card_effect = @card[:effect] || @card["effect"] || %{}
        talent_bonus = min(length(@talent_cards), 2)

        # Calculate final effect with talent bonus
        final_effect = Map.new(card_effect, fn {key, val} -> {key, val + talent_bonus} end)

        # Calculate preview of new parameters
        new_params = calculate_new_params(@current_params, final_effect)

        can_afford = @current_currency >= card_cost
      %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
        phx-click="cancel_action_confirm"
        role="dialog"
        aria-modal="true"
        aria-labelledby="action-confirm-title"
        {@rest}
      >
        <div
          class="relative bg-washi border-4 border-double border-shu rounded-lg shadow-2xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto"
          phx-click-away="cancel_action_confirm"
        >
          <button
            class="absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30 transition-colors"
            phx-click="cancel_action_confirm"
            aria-label="モーダルを閉じる"
          >
            <span class="text-lg font-bold">×</span>
          </button>

          <div class="p-6">
            <h2 id="action-confirm-title" class="text-2xl font-bold text-sumi mb-4">アクションの確認</h2>

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
            <div class="mb-4 p-3 bg-kin/10 border border-kin/30 rounded">
              <div class="flex justify-between items-center">
                <span class="text-sm font-semibold text-sumi">コスト（空環）</span>
                <div class="flex items-center gap-2">
                  <span class={[
                    "text-lg font-bold",
                    if(can_afford, do: "text-kin", else: "text-shu")
                  ]}>
                    {card_cost}
                  </span>
                  <span class="text-sm text-sumi/60">
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
              <div class="text-sm font-semibold text-sumi mb-2">効果プレビュー</div>
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
              <div class="mb-4 p-3 bg-washi border border-sumi/20 rounded">
                <div class="text-sm font-semibold text-sumi mb-2">パラメータ変化のプレビュー</div>
                <div class="space-y-1 text-xs">
                  <%= if Map.has_key?(@current_params, :forest) or Map.has_key?(@current_params, :f) do %>
                    <div class="flex justify-between">
                      <span class="text-matsu">F (森)</span>
                      <span class="text-sumi">
                        {Map.get(@current_params, :forest, Map.get(@current_params, :f, 0))}
                        →
                        {Map.get(new_params, :forest, Map.get(new_params, :f, 0))}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :culture) or Map.has_key?(@current_params, :k) do %>
                    <div class="flex justify-between">
                      <span class="text-sakura">K (文化)</span>
                      <span class="text-sumi">
                        {Map.get(@current_params, :culture, Map.get(@current_params, :k, 0))}
                        →
                        {Map.get(new_params, :culture, Map.get(new_params, :k, 0))}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :social) or Map.has_key?(@current_params, :s) do %>
                    <div class="flex justify-between">
                      <span class="text-kohaku">S (社会)</span>
                      <span class="text-sumi">
                        {Map.get(@current_params, :social, Map.get(@current_params, :s, 0))}
                        →
                        {Map.get(new_params, :social, Map.get(new_params, :s, 0))}
                      </span>
                    </div>
                  <% end %>
                  <%= if Map.has_key?(@current_params, :currency) or Map.has_key?(@current_params, :p) do %>
                    <div class="flex justify-between">
                      <span class="text-kin">P (空環)</span>
                      <span class="text-sumi">
                        {Map.get(@current_params, :currency, Map.get(@current_params, :p, 0))}
                        →
                        {Map.get(new_params, :currency, Map.get(new_params, :p, 0))}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Action Buttons -->
            <div class="flex gap-3 mt-6">
              <button
                class={[
                  "flex-1 px-4 py-3 rounded-lg border-2 font-semibold transition-colors",
                  if(can_afford,
                    do: "bg-shu text-washi border-shu hover:bg-shu/90",
                    else: "bg-sumi/20 text-sumi/50 border-sumi/30 cursor-not-allowed"
                  )
                ]}
                phx-click={if can_afford, do: "confirm_action", else: nil}
                disabled={not can_afford}
                aria-label="アクションを実行"
              >
                実行する
              </button>
              <button
                class="flex-1 px-4 py-3 rounded-lg border-2 border-sumi bg-washi text-sumi hover:bg-sumi/5 transition-colors font-semibold"
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
    Map.merge(current_params, effect, fn _key, current_val, effect_val ->
      current_val + effect_val
    end)
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
    ending_type = determine_ending_type(assigns.game_status, assigns.life_index, assigns.final_stats)
    
    ending_data = get_ending_data(ending_type)
    
    assigns =
      assigns
      |> assign(:ending_type, ending_type)
      |> assign(:ending_data, ending_data)

    ~H"""
    <%= if @show && @game_status != :playing do %>
      <div
        id={@id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md"
        role="dialog"
        aria-modal="true"
        aria-labelledby="ending-title"
        {@rest}
      >
        <div class="relative bg-washi border-4 border-double rounded-lg shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto animate-fade-in">
          <!-- Ending Header -->
          <div class={[
            "p-8 text-center border-b-4 border-double",
            @ending_type == :blessing && "bg-kin/10 border-kin",
            @ending_type == :purification && "bg-matsu/10 border-matsu",
            @ending_type == :uncertain && "bg-kohaku/10 border-kohaku",
            @ending_type == :lament && "bg-shu/10 border-shu",
            @ending_type == :instant_loss && "bg-sumi/20 border-sumi"
          ]}>
            <div class="text-6xl mb-4">{@ending_data.icon}</div>
            <h1 id="ending-title" class="text-3xl md:text-4xl font-bold mb-2 writing-mode-vertical">
              {@ending_data.title}
            </h1>
            <p class="text-lg text-sumi/80 mt-4">{@ending_data.subtitle}</p>
          </div>

          <!-- Ending Description -->
          <div class="p-6 md:p-8">
            <div class="prose prose-sumi max-w-none mb-6">
              <p class="text-base leading-relaxed text-sumi">{@ending_data.description}</p>
            </div>

            <!-- Final Statistics -->
            <div class="mb-6 p-4 bg-washi border-2 border-sumi/20 rounded-lg">
              <h2 class="text-lg font-bold text-sumi mb-4">最終結果</h2>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="text-center">
                  <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-1">Life Index</div>
                  <div class="text-2xl font-bold text-shu">{@life_index}</div>
                </div>
                <div class="text-center">
                  <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-1">F (森)</div>
                  <div class="text-xl font-bold text-matsu">{@final_stats[:forest] || @final_stats["forest"] || 0}</div>
                </div>
                <div class="text-center">
                  <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-1">K (文化)</div>
                  <div class="text-xl font-bold text-sakura">{@final_stats[:culture] || @final_stats["culture"] || 0}</div>
                </div>
                <div class="text-center">
                  <div class="text-xs uppercase tracking-[0.2em] text-sumi/60 mb-1">S (社会)</div>
                  <div class="text-xl font-bold text-kohaku">{@final_stats[:social] || @final_stats["social"] || 0}</div>
                </div>
              </div>
              <div class="mt-4 text-center text-sm text-sumi/70">
                ターン数: {@turn} / {@max_turns}
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex flex-col sm:flex-row gap-3 mt-6">
              <button
                class="flex-1 px-6 py-3 bg-shu text-washi rounded-lg border-2 border-sumi font-semibold hover:bg-shu/90 transition-colors"
                phx-click="restart_game"
                aria-label="新しいゲームを開始"
              >
                新しいゲームを開始
              </button>
              <button
                class="flex-1 px-6 py-3 bg-washi text-sumi rounded-lg border-2 border-sumi hover:bg-sumi/5 transition-colors font-semibold"
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

  defp determine_ending_type(:lost, _life_index, final_stats) do
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

  defp determine_ending_type(:won, life_index, _final_stats) do
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
      description: "20年の歳月を経て、世界は見事に再生しました。森は豊かに茂り、文化は花開き、コミュニティは強く結ばれています。八百万の神々は、あなたたちの努力を祝福し、この世界に永遠の調和をもたらしました。"
    }
  end

  defp get_ending_data(:purification) do
    %{
      icon: "🌿",
      title: "浄化の兆し",
      subtitle: "Signs of Purification",
      description: "世界は回復の道を歩み始めています。まだ完全ではありませんが、希望の光が見えています。森、文化、コミュニティは徐々に力を取り戻しつつあります。神々は、この世界の未来に期待を寄せています。"
    }
  end

  defp get_ending_data(:uncertain) do
    %{
      icon: "🌙",
      title: "揺らぎの未来",
      subtitle: "Uncertain Future",
      description: "20年が過ぎましたが、世界の未来はまだ定まっていません。いくつかの改善は見られますが、まだ多くの課題が残されています。神々は、この世界がどちらの方向へ向かうのか、見守り続けています。"
    }
  end

  defp get_ending_data(:lament) do
    %{
      icon: "🔥",
      title: "神々の嘆き",
      subtitle: "Lament of the Gods",
      description: "20年の歳月を経ても、世界は十分に回復できませんでした。森、文化、コミュニティのいずれかが危機に瀕しています。神々は、この世界の現状を嘆き、さらなる努力を求めています。"
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
  attr :selected_role, :atom, default: nil, values: [:forest_guardian, :culture_keeper, :community_light, :akasha_engineer]
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
        color: "matsu",
        icon: "🌲"
      },
      %{
        id: :culture_keeper,
        name: "文化の継承者",
        name_en: "Culture Keeper",
        focus: "K (Culture) の継承と発展",
        description: "伝統、芸術、知恵を継承し、発展させる役割。文化の価値を守りながら、新しい表現を生み出します。",
        color: "sakura",
        icon: "🌸"
      },
      %{
        id: :community_light,
        name: "コミュニティの灯火",
        name_en: "Community Light",
        focus: "S (Social) の結束と強化",
        description: "人々のつながりを深め、コミュニティを強くする役割。信頼関係を築き、協力の輪を広げます。",
        color: "kohaku",
        icon: "🕯️"
      },
      %{
        id: :akasha_engineer,
        name: "空環エンジニア",
        name_en: "Akasha Engineer",
        focus: "P (Akasha) の循環と技術",
        description: "空環マネーの循環を管理し、技術を発展させる役割。経済システムを最適化し、持続可能な循環を実現します。",
        color: "kin",
        icon: "⚡"
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
        <div class="relative bg-washi border-4 border-double border-sumi rounded-lg shadow-2xl max-w-5xl w-full max-h-[90vh] overflow-y-auto animate-fade-in">
          <!-- Header -->
          <div class="p-6 md:p-8 text-center border-b-4 border-double border-sumi">
            <h1 id="role-selection-title" class="text-2xl md:text-3xl font-bold text-sumi mb-2 writing-mode-vertical">
              役割を選択
            </h1>
            <p class="text-sm md:text-base text-sumi/70">あなたの役割を選んでください</p>
          </div>

          <!-- Role Cards -->
          <div class="p-6 md:p-8">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
              <%= for role <- @roles do %>
                <%
                  is_selected = @selected_role == role.id
                  is_available = Enum.empty?(@available_roles) || Enum.member?(@available_roles, role.id)
                  color_class = case role.color do
                    "matsu" -> "border-matsu bg-matsu/5"
                    "sakura" -> "border-sakura bg-sakura/5"
                    "kohaku" -> "border-kohaku bg-kohaku/5"
                    "kin" -> "border-kin bg-kin/5"
                    _ -> "border-sumi bg-sumi/5"
                  end
                %>
                <div
                  class={[
                    "relative p-6 rounded-lg border-4 border-double transition-all duration-300 cursor-pointer",
                    color_class,
                    if(is_selected,
                      do: "ring-4 ring-shu/50 scale-105 shadow-xl",
                      else: "hover:scale-105 hover:shadow-lg"
                    ),
                    if(not is_available, do: "opacity-50 cursor-not-allowed", else: "")
                  ]}
                  phx-click={if is_available, do: "select_role", else: nil}
                  phx-value-role-id={role.id}
                  role="button"
                  aria-label={"役割: #{role.name}"}
                  aria-pressed={is_selected}
                >
                  <%= if is_selected do %>
                    <div class="absolute top-2 right-2 w-8 h-8 bg-shu text-washi rounded-full flex items-center justify-center text-lg">
                      ✓
                    </div>
                  <% end %>

                  <div class="text-center mb-4">
                    <div class="text-4xl mb-2">{role.icon}</div>
                    <h2 class="text-xl md:text-2xl font-bold text-sumi mb-1 writing-mode-vertical">
                      {role.name}
                    </h2>
                    <p class="text-xs text-sumi/60 mb-2">{role.name_en}</p>
                  </div>

                  <div class="mb-3">
                    <div class="text-sm font-semibold text-sumi/80 mb-1">焦点</div>
                    <p class="text-sm text-sumi">{role.focus}</p>
                  </div>

                  <div>
                    <div class="text-sm font-semibold text-sumi/80 mb-1">説明</div>
                    <p class="text-xs leading-relaxed text-sumi/70">{role.description}</p>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Action Buttons -->
            <%= if @selected_role do %>
              <div class="mt-6 flex flex-col sm:flex-row gap-3">
                <button
                  class="flex-1 px-6 py-3 bg-shu text-washi rounded-lg border-2 border-sumi font-semibold hover:bg-shu/90 transition-colors"
                  phx-click="confirm_role_selection"
                  aria-label="役割を確定"
                >
                  役割を確定
                </button>
                <button
                  class="flex-1 px-6 py-3 bg-washi text-sumi rounded-lg border-2 border-sumi hover:bg-sumi/5 transition-colors font-semibold"
                  phx-click="cancel_role_selection"
                  aria-label="キャンセル"
                >
                  キャンセル
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a toast notification with Miyabi theme.
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
        "fixed top-4 right-4 z-50 min-w-[300px] max-w-md p-4 rounded-lg border-2 shadow-lg animate-slide-in-right",
        @kind == :success && "bg-washi border-matsu text-sumi",
        @kind == :error && "bg-washi border-shu text-sumi",
        @kind == :info && "bg-washi border-sumi text-sumi",
        @kind == :warning && "bg-washi border-kohaku text-sumi",
        @class
      ]}
      role="alert"
      aria-live="assertive"
      {@rest}
    >
      <div class="flex items-start gap-3">
        <div class={[
          "flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold",
          @kind == :success && "bg-matsu/20 text-matsu",
          @kind == :error && "bg-shu/20 text-shu",
          @kind == :info && "bg-sumi/20 text-sumi",
          @kind == :warning && "bg-kohaku/20 text-kohaku"
        ]}>
          {if @kind == :success, do: "✓", else: if(@kind == :error, do: "✕", else: "ℹ")}
        </div>
        <p class="flex-1 text-sm leading-relaxed">{@message}</p>
      </div>
    </div>
    """
  end
end
