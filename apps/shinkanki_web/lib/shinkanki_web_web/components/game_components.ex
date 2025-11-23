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
