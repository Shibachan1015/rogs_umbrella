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
    ~H"""
    <div
      class={[
        "relative w-24 h-36 bg-washi border-2 border-sumi shadow-md flex flex-col items-center p-2 transition-transform hover:-translate-y-2 cursor-pointer select-none",
        "before:content-[''] before:absolute before:top-1 before:w-2 before:h-2 before:bg-sumi/10 before:rounded-full",
        @class
      ]}
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
        "w-16 h-16 rounded-full border-4 border-double flex items-center justify-center transition-transform active:scale-95 shadow-sm hover:shadow-md",
        @color == "shu" && "border-shu text-shu bg-washi hover:bg-shu/5",
        @color == "sumi" && "border-sumi text-sumi bg-washi hover:bg-sumi/5",
        @color == "matsu" && "border-matsu text-matsu bg-washi hover:bg-matsu/5",
        @class
      ]}
      {@rest}
    >
      <span class="font-serif font-bold text-sm writing-mode-vertical leading-none">
        {@label}
      </span>
    </button>
    """
  end
end
