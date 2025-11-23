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
