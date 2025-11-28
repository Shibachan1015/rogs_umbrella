defmodule ShinkankiWebWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary trds), default: "primary"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => ["btn", "btn-primary"],
      "trds" =>
        "inline-flex items-center justify-center gap-2 rounded-trds-lg border border-trds-outline-strong bg-trds-surface-glass px-4 py-2 font-semibold tracking-[0.3em] text-trds-text-primary uppercase transition duration-trds ease-trds trds-focusable hover:-translate-y-0.5 hover:shadow-trds-gold disabled:opacity-50 disabled:cursor-not-allowed",
      nil => ["btn", "btn-primary", "btn-soft"]
    }

    # Extract accessibility attributes
    aria_label = rest[:aria_label] || rest[:"aria-label"]
    aria_label_attr = if aria_label, do: [{"aria-label", aria_label}], else: []
    button_type = rest[:type] || "button"
    is_link = rest[:href] || rest[:navigate] || rest[:patch]

    assigns =
      assigns
      |> assign_new(:class, fn ->
        variants
        |> Map.fetch!(assigns[:variant])
        |> List.wrap()
      end)
      |> assign(:aria_label_attr, aria_label_attr)
      |> assign(:button_type, button_type)
      |> assign(:is_link, is_link)

    if is_link do
      ~H"""
      <.link
        class={@class |> List.wrap()}
        role="button"
        tabindex="0"
        {@aria_label_attr}
        {@rest}
      >
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button
        class={@class |> List.wrap()}
        type={@button_type}
        {@aria_label_attr}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"
  attr :variant, :string, default: "default", values: ~w(default trds)

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    error_id = if assigns.errors != [], do: "#{assigns.id}-error", else: nil
    aria_attrs = [
      if(error_id, do: {"aria-describedby", error_id}, else: nil),
      if(assigns.errors != [], do: {"aria-invalid", "true"}, else: nil)
    ] |> Enum.reject(&is_nil/1)

    assigns =
      assigns
      |> assign_new(:checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)
      |> assign(:error_id, error_id)
      |> assign(:aria_attrs, aria_attrs)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={checkbox_class(assigns)}
            {@aria_attrs}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors} id={@error_id}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    error_id = if assigns.errors != [], do: "#{assigns.id}-error", else: nil
    aria_attrs = [
      if(error_id, do: {"aria-describedby", error_id}, else: nil),
      if(assigns.errors != [], do: {"aria-invalid", "true"}, else: nil),
      if(assigns[:label], do: {"aria-label", assigns[:label]}, else: nil)
    ] |> Enum.reject(&is_nil/1)

    assigns =
      assigns
      |> assign(:error_id, error_id)
      |> assign(:aria_attrs, aria_attrs)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={
            default_input_class(assigns, :select)
            |> List.wrap()
            |> maybe_add_error_class(assigns, "select-error")
          }
          multiple={@multiple}
          {@aria_attrs}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors} id={@error_id}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    error_id = if assigns.errors != [], do: "#{assigns.id}-error", else: nil
    aria_attrs = [
      if(error_id, do: {"aria-describedby", error_id}, else: nil),
      if(assigns.errors != [], do: {"aria-invalid", "true"}, else: nil),
      if(assigns[:label], do: {"aria-label", assigns[:label]}, else: nil)
    ] |> Enum.reject(&is_nil/1)

    assigns =
      assigns
      |> assign(:error_id, error_id)
      |> assign(:aria_attrs, aria_attrs)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={
            default_input_class(assigns, :textarea)
            |> List.wrap()
            |> maybe_add_error_class(assigns, "textarea-error")
          }
          {@aria_attrs}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors} id={@error_id}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    error_id = if assigns.errors != [], do: "#{assigns.id}-error", else: nil
    aria_attrs = [
      if(error_id, do: {"aria-describedby", error_id}, else: nil),
      if(assigns.errors != [], do: {"aria-invalid", "true"}, else: nil),
      if(assigns[:label], do: {"aria-label", assigns[:label]}, else: nil)
    ] |> Enum.reject(&is_nil/1)

    assigns =
      assigns
      |> assign(:error_id, error_id)
      |> assign(:aria_attrs, aria_attrs)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={
            default_input_class(assigns, :text)
            |> List.wrap()
            |> maybe_add_error_class(assigns, "input-error")
          }
          {@aria_attrs}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors} id={@error_id}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  attr :id, :string, default: nil
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p
      :if={@id}
      id={@id}
      class="mt-1.5 flex gap-2 items-center text-sm text-shu error-shake"
      role="alert"
      aria-live="polite"
    >
      <.icon name="hero-exclamation-circle" class="size-4 flex-shrink-0" aria-hidden="true" />
      <span>{render_slot(@inner_block)}</span>
    </p>
    <p
      :if={!@id}
      class="mt-1.5 flex gap-2 items-center text-sm text-shu error-shake"
      role="alert"
      aria-live="polite"
    >
      <.icon name="hero-exclamation-circle" class="size-4 flex-shrink-0" aria-hidden="true" />
      <span>{render_slot(@inner_block)}</span>
    </p>
    """
  end

  defp checkbox_class(%{class: class}) when not is_nil(class), do: class

  defp checkbox_class(%{variant: "trds"}) do
    "size-4 rounded-trds-sm border border-trds-outline-soft bg-trds-surface text-trds-text-primary focus:ring-0 focus:outline-none focus:border-trds-outline-strong accent-shu trds-focusable"
  end

  defp checkbox_class(_assigns), do: "checkbox checkbox-sm"

  defp default_input_class(%{class: class}, _type) when not is_nil(class), do: class

  defp default_input_class(%{variant: "trds"}, type) do
    base = [
      "w-full rounded-trds-md border border-trds-outline-soft bg-trds-surface-glass text-trds-text-primary placeholder:text-trds-text-secondary/60 focus:border-trds-outline-strong focus:ring-0 focus:outline-none transition duration-trds ease-trds trds-focusable"
    ]

    case type do
      :textarea -> base ++ ["min-h-[6rem]"]
      :select -> base ++ ["pr-10"]
      _ -> base
    end
  end

  defp default_input_class(_assigns, :textarea), do: "w-full textarea"
  defp default_input_class(_assigns, :select), do: "w-full select"
  defp default_input_class(_assigns, _type), do: "w-full input"

  defp maybe_add_error_class(class_list, %{errors: []}, _fallback), do: class_list

  defp maybe_add_error_class(class_list, assigns, fallback) do
    class_list ++ [default_error_class(assigns, fallback)]
  end

  defp default_error_class(%{error_class: class}, _fallback) when not is_nil(class), do: class
  defp default_error_class(%{variant: "trds"}, _fallback), do: "border-shu/70 bg-shu/5 text-shu"
  defp default_error_class(_assigns, fallback), do: fallback

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">Actions</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  Renders a TRDS-styled modal dialog.

  ## Examples

      <.modal id="confirm-modal" show={@show_modal}>
        <:title>確認</:title>
        <:body>この操作を実行しますか？</:body>
        <:footer>
          <.button phx-click="confirm">実行</.button>
          <.button phx-click="cancel">キャンセル</.button>
        </:footer>
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :variant, :string, default: "default", values: ~w(default trds)
  attr :rest, :global

  slot :title
  slot :body, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "fixed inset-0 z-50 overflow-y-auto",
        if(@show, do: "block", else: "hidden")
      ]}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      aria-describedby={"#{@id}-body"}
      phx-click-away={JS.hide(to: "##{@id}")}
      {@rest}
    >
      <div class="fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity" aria-hidden="true"></div>
      <div class="flex min-h-full items-center justify-center p-4">
        <div
          class={[
            "relative w-full max-w-lg transform overflow-hidden rounded-lg shadow-xl transition-all",
            if(@variant == "trds",
              do: "bg-trds-surface-glass border border-trds-outline-soft backdrop-blur-xl",
              else: "bg-base-100"
            )
          ]}
          phx-click-away={JS.hide(to: "##{@id}")}
        >
          <div class="px-6 py-4">
            <div :if={@title != []} class="mb-4">
              <h3 id={"#{@id}-title"} class={[
                "text-lg font-semibold",
                if(@variant == "trds",
                  do: "text-trds-text-primary tracking-[0.2em] uppercase",
                  else: "text-base-content"
                )
              ]}>
                {render_slot(@title)}
              </h3>
            </div>
            <div id={"#{@id}-body"} class={[
              if(@variant == "trds", do: "text-trds-text-secondary", else: "text-base-content")
            ]}>
              {render_slot(@body)}
            </div>
          </div>
          <div :if={@footer != []} class={[
            "px-6 py-4 border-t",
            if(@variant == "trds",
              do: "border-trds-outline-soft bg-trds-surface/50",
              else: "border-base-300 bg-base-200"
            )
          ]}>
            <div class="flex justify-end gap-2">
              {render_slot(@footer)}
            </div>
          </div>
          <button
            type="button"
            class={[
              "absolute top-4 right-4 rounded-full p-2 transition-colors",
              if(@variant == "trds",
                do: "text-trds-text-secondary hover:bg-trds-surface hover:text-trds-text-primary",
                else: "text-base-content hover:bg-base-200"
              )
            ]}
            phx-click={JS.hide(to: "##{@id}")}
            aria-label="モーダルを閉じる"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(ShinkankiWebWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(ShinkankiWebWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Renders a TRDS-styled loading indicator.

  ## Examples

      <.loading_indicator />
      <.loading_indicator text="読み込み中..." />
      <.loading_indicator variant="trds" size="lg" />
  """
  attr :text, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default trds)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :rest, :global

  def loading_indicator(assigns) do
    size_classes = %{
      "sm" => "size-4",
      "md" => "size-8",
      "lg" => "size-12"
    }

    spinner_class = [
      "animate-spin rounded-full border-2 border-t-transparent",
      size_classes[assigns.size],
      if(assigns.variant == "trds",
        do: "border-trds-outline-strong",
        else: "border-primary"
      )
    ]

    text_class = [
      "text-sm",
      if(assigns.variant == "trds",
        do: "text-trds-text-secondary",
        else: "text-base-content/70"
      )
    ]

    assigns =
      assigns
      |> assign(:spinner_class, spinner_class)
      |> assign(:text_class, text_class)

    ~H"""
    <div class="flex flex-col items-center justify-center gap-2" {@rest}>
      <div class={@spinner_class} role="status" aria-label="読み込み中">
        <span class="sr-only">読み込み中</span>
      </div>
      <p :if={@text} class={@text_class}>
        {@text}
      </p>
    </div>
    """
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
