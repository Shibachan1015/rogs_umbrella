defmodule ShinkankiWebWeb.GameLive do
  use ShinkankiWebWeb, :live_view

  alias RogsComm.PubSub
  alias RogsComm.Messages

  def mount(params, _session, socket) do
    # Get room_id from params or use default from game_state
    room_id = params["room_id"] || mock_game_state().room

    socket =
      socket
      |> assign(:game_state, mock_game_state())
      |> assign(:room_id, room_id)
      |> assign(:hand_cards, mock_hand_cards())
      |> assign(:action_buttons, mock_actions())
      |> assign(:chat_form, chat_form())
      |> assign(:user_id, Ecto.UUID.generate())
      |> assign(:user_email, "anonymous")
      |> assign(:toasts, [])
      |> assign(:selected_card_id, nil)

    socket =
      if connected?(socket) do
        # Subscribe to rogs_comm PubSub for real-time chat updates
        topic = "room:#{room_id}"
        Phoenix.PubSub.subscribe(PubSub, topic)

        # Load initial messages from rogs_comm
        messages = load_messages(room_id)
        stream(socket, :chat_messages, messages, reset: true)
      else
        stream(socket, :chat_messages, [], reset: true)
      end

    {:ok, socket, layout: {ShinkankiWebWeb.Layouts, :game}}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen w-screen overflow-hidden flex flex-col">
      <div class="flex-1 flex overflow-hidden relative">
        <!-- Sidebar -->
        <aside
          class="fixed lg:static inset-y-0 left-0 w-72 sm:w-80 bg-washi-dark border-r-2 border-sumi flex flex-col z-20 shadow-lg lg:translate-x-0 -translate-x-full transition-transform duration-300"
          id="sidebar"
          role="complementary"
          aria-label="ゲーム情報とチャット"
          aria-hidden="false"
        >
          <!-- Mobile toggle button (outside sidebar) -->
          <button
            class="lg:hidden fixed left-0 top-4 z-30 w-10 h-10 bg-shu text-washi rounded-r-lg flex items-center justify-center shadow-md"
            phx-click={
              JS.toggle(to: "#sidebar", in: {"translate-x-0", "-translate-x-full"}, time: 300)
            }
            aria-label="サイドバーを開く"
            aria-expanded="false"
            id="sidebar-toggle"
          >
            <.icon name="hero-bars-3" class="w-5 h-5" />
          </button>
          <!-- Close button inside sidebar -->
          <button
            class="lg:hidden absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30"
            phx-click={
              JS.toggle(to: "#sidebar", in: {"translate-x-0", "-translate-x-full"}, time: 300)
            }
            aria-label="サイドバーを閉じる"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
          <div class="p-4 border-b-2 border-sumi text-center space-y-1">
            <div class="text-[10px] uppercase tracking-[0.6em] text-sumi/60" aria-label="ルーム名">
              Room
            </div>
            <div
              class="text-2xl font-bold tracking-[0.5em] text-shu"
              aria-label={"ルーム: #{@game_state.room}"}
            >
              {@game_state.room}
            </div>
            <div
              class="text-xs text-sumi/60"
              aria-label="ターン: {@game_state.turn} / {@game_state.max_turns}"
            >
              Turn {@game_state.turn} / {@game_state.max_turns}
            </div>
          </div>

          <div class="grid grid-cols-2 gap-2 sm:gap-3 px-3 sm:px-4 py-2 sm:py-3 border-b-2 border-sumi text-xs">
            <div class="bg-washi p-2 sm:p-3 rounded shadow-inner border border-sumi/20">
              <div class="uppercase tracking-[0.2em] sm:tracking-[0.3em] text-sumi/50 mb-1 text-[10px] sm:text-xs">
                Currency
              </div>
              <div class="text-base sm:text-lg font-semibold text-kin">{@game_state.currency}</div>
            </div>
            <div class="bg-washi p-2 sm:p-3 rounded shadow-inner border border-sumi/20">
              <div class="uppercase tracking-[0.2em] sm:tracking-[0.3em] text-sumi/50 mb-1 text-[10px] sm:text-xs">
                Demurrage
              </div>
              <div class="text-base sm:text-lg font-semibold text-sumi">{@game_state.demurrage}</div>
            </div>
          </div>

          <div
            class="flex-1 overflow-y-auto p-4 space-y-3 scrollbar-thin scrollbar-thumb-sumi scrollbar-track-transparent"
            id="chat-container"
            phx-hook="ChatScroll"
            role="log"
            aria-label="チャットログ"
            aria-live="polite"
            aria-atomic="false"
          >
            <div class="text-[10px] uppercase tracking-[0.5em] text-sumi/50">Chat Log</div>
            <div id="chat-messages" phx-update="stream" class="space-y-3">
              <div
                :for={{id, msg} <- @streams.chat_messages}
                id={id}
                class="chat-message border border-sumi/15 rounded-lg bg-washi p-3 shadow-sm"
                phx-mounted={
                  JS.add_class("new-message", to: "##{id}")
                  |> JS.remove_class("new-message", time: 2000, to: "##{id}")
                }
                role="article"
                aria-label={"メッセージ from #{msg.user_email || msg.author}"}
              >
                <div class="flex justify-between text-[10px] uppercase tracking-[0.4em] text-sumi/50">
                  <span class="font-semibold" aria-label="送信者">
                    {msg.user_email || msg.author}
                  </span>
                  <time
                    class="text-sumi/40"
                    datetime={if msg.inserted_at, do: DateTime.to_iso8601(msg.inserted_at), else: ""}
                    aria-label="送信時刻"
                  >
                    {format_time(msg.inserted_at || msg.sent_at)}
                  </time>
                </div>
                <p class="text-sm text-sumi mt-2 leading-relaxed">{msg.content || msg.body}</p>
              </div>
            </div>
          </div>

          <div
            class="border-t-2 border-sumi bg-washi-dark/70 p-4 space-y-3"
            role="region"
            aria-label="メッセージ送信"
          >
            <div class="uppercase tracking-[0.4em] text-[10px] text-sumi/50">Send Message</div>
            <.form
              for={@chat_form}
              id="chat-form"
              phx-submit="send_chat"
              phx-change="validate_chat"
              class="space-y-3"
              role="form"
              aria-label="チャットメッセージ送信フォーム"
            >
              <.input
                field={@chat_form[:body]}
                type="textarea"
                placeholder="想いを紡ぐ..."
                class="bg-washi border border-sumi/20 focus:border-shu focus:ring-0 min-h-20 text-sm"
                phx-hook="ChatInput"
                autofocus
                aria-label="メッセージ本文"
                aria-describedby="chat-body-help"
              />
              <p id="chat-body-help" class="sr-only">メッセージを入力してください。Enterキーで送信、Shift+Enterで改行します。</p>

              <div class="flex items-center gap-2">
                <.input
                  field={@chat_form[:author]}
                  type="text"
                  class="bg-washi border border-sumi/20 focus:border-sumi focus:ring-0 text-xs uppercase tracking-[0.4em]"
                  placeholder="署名"
                  aria-label="送信者名"
                />
                <button
                  type="submit"
                  class="ml-auto px-4 py-2 bg-shu text-washi rounded-full text-xs tracking-[0.3em] hover:bg-shu/90 transition shadow flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  phx-disable-with="送信中..."
                  aria-label="メッセージを送信"
                >
                  <span class="phx-submit-loading:hidden">送信</span>
                  <span class="hidden phx-submit-loading:inline-flex items-center gap-2">
                    <svg
                      class="animate-spin h-3 w-3"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    送信中...
                  </span>
                </button>
              </div>
            </.form>
          </div>
        </aside>
        
    <!-- Main Board -->
        <main
          class="flex-1 relative overflow-hidden flex items-center justify-center p-2 sm:p-4 md:p-8 lg:ml-0"
          role="main"
          aria-label="ゲームボード"
        >
          <div
            class="relative w-full max-w-[600px] sm:max-w-[700px] md:max-w-[800px] aspect-square bg-washi rounded-full border-2 sm:border-4 border-sumi flex items-center justify-center shadow-xl"
            role="region"
            aria-label="Life Index表示"
          >
            <!-- Life Index Circle -->
            <div
              class="absolute inset-0 m-auto w-[75%] max-w-[600px] aspect-square rounded-full border-2 border-sumi/20 flex items-center justify-center life-index-ring"
              aria-label={"Life Index: #{life_index(@game_state)}"}
              role="meter"
              aria-valuenow={life_index(@game_state)}
              aria-valuemin="0"
              aria-valuemax={@game_state.life_index_target}
            >
              <!-- Circular progress SVG -->
              <svg
                class="absolute inset-0 w-full h-full circular-progress"
                viewBox="0 0 200 200"
                aria-hidden="true"
              >
                <circle
                  cx="100"
                  cy="100"
                  r="90"
                  fill="none"
                  stroke="rgba(28, 28, 28, 0.1)"
                  stroke-width="8"
                />
                <circle
                  cx="100"
                  cy="100"
                  r="90"
                  fill="none"
                  stroke="rgba(211, 56, 28, 0.3)"
                  stroke-width="8"
                  stroke-dasharray={circumference()}
                  stroke-dashoffset={
                    circumference_offset(life_index(@game_state), @game_state.life_index_target)
                  }
                  stroke-linecap="round"
                  class="transition-all duration-1000"
                />
              </svg>
              <div class="text-center relative z-10 px-2 sm:px-4">
                <div class="text-sm sm:text-lg md:text-2xl uppercase tracking-[0.3em] sm:tracking-[0.4em] text-sumi/60">
                  Life Index
                </div>
                <div
                  id="life-index-value"
                  class="text-3xl sm:text-4xl md:text-7xl font-bold text-shu font-serif mb-1 sm:mb-2 life-index-value"
                  phx-update="ignore"
                >
                  {life_index(@game_state)}
                </div>
                <div class="text-[9px] sm:text-[10px] md:text-xs text-sumi/50 uppercase tracking-[0.3em] sm:tracking-[0.5em]">
                  Target {@game_state.life_index_target} / Turn {@game_state.turn} of {@game_state.max_turns}
                </div>
              </div>
            </div>
            
    <!-- Gauges -->
            <div
              class="absolute top-2 sm:top-4 md:top-10 left-1/2 -translate-x-1/2 flex flex-col items-center drop-shadow-sm"
              role="group"
              aria-label="Forest (F) ゲージ"
            >
              <span class="text-matsu font-bold text-xs sm:text-sm md:text-xl">Forest (F)</span>
              <div
                class="w-20 sm:w-24 md:w-40 h-2 sm:h-3 md:h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi relative"
                role="progressbar"
                aria-valuenow={@game_state.forest}
                aria-valuemin="0"
                aria-valuemax="20"
                aria-label={"Forest: #{@game_state.forest}"}
              >
                <div
                  id="forest-gauge-bar"
                  class="h-full bg-matsu transition-all duration-700 ease-out"
                  style={"width: #{gauge_width(@game_state.forest)}%"}
                  phx-update="ignore"
                >
                </div>
                <span class="absolute inset-0 flex items-center justify-center text-[10px] md:text-xs font-semibold text-sumi/80">
                  {@game_state.forest}
                </span>
              </div>
            </div>

            <div
              class="absolute bottom-8 sm:bottom-12 md:bottom-20 left-2 sm:left-4 md:left-20 flex flex-col items-center drop-shadow-sm"
              role="group"
              aria-label="Culture (K) ゲージ"
            >
              <span class="text-sakura font-bold text-xs sm:text-sm md:text-xl">Culture (K)</span>
              <div
                class="w-16 sm:w-20 md:w-32 h-2 sm:h-3 md:h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi relative"
                role="progressbar"
                aria-valuenow={@game_state.culture}
                aria-valuemin="0"
                aria-valuemax="20"
                aria-label={"Culture: #{@game_state.culture}"}
              >
                <div
                  id="culture-gauge-bar"
                  class="h-full bg-sakura transition-all duration-700 ease-out"
                  style={"width: #{gauge_width(@game_state.culture)}%"}
                  phx-update="ignore"
                >
                </div>
                <span class="absolute inset-0 flex items-center justify-center text-[10px] md:text-xs font-semibold text-sumi/80">
                  {@game_state.culture}
                </span>
              </div>
            </div>

            <div
              class="absolute bottom-8 sm:bottom-12 md:bottom-20 right-2 sm:right-4 md:right-20 flex flex-col items-center drop-shadow-sm"
              role="group"
              aria-label="Social (S) ゲージ"
            >
              <span class="text-kohaku font-bold text-xs sm:text-sm md:text-xl">Social (S)</span>
              <div
                class="w-16 sm:w-20 md:w-32 h-2 sm:h-3 md:h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi relative"
                role="progressbar"
                aria-valuenow={@game_state.social}
                aria-valuemin="0"
                aria-valuemax="20"
                aria-label={"Social: #{@game_state.social}"}
              >
                <div
                  id="social-gauge-bar"
                  class="h-full bg-kohaku transition-all duration-700 ease-out"
                  style={"width: #{gauge_width(@game_state.social)}%"}
                  phx-update="ignore"
                >
                </div>
                <span class="absolute inset-0 flex items-center justify-center text-[10px] md:text-xs font-semibold text-sumi/80">
                  {@game_state.social}
                </span>
              </div>
            </div>
          </div>
          
    <!-- Actions (Stamps) -->
          <div
            class="absolute bottom-2 sm:bottom-4 md:bottom-8 right-2 sm:right-4 md:right-8 flex gap-1 sm:gap-2 md:gap-4 flex-wrap justify-end max-w-[50%]"
            role="toolbar"
            aria-label="アクションボタン"
          >
            <.hanko_btn
              :for={button <- @action_buttons}
              label={button.label}
              color={button.color}
              class="shadow-lg hover:-translate-y-1 transition w-10 h-10 sm:w-12 sm:h-12 md:w-16 md:h-16"
              aria-label={button.label <> "を実行"}
              phx-click="execute_action"
              phx-value-action={button.action || button.label}
            />
          </div>
        </main>
      </div>
      
    <!-- Bottom Hand -->
      <div
        class="h-32 md:h-48 bg-washi-dark border-t-4 border-sumi z-30 relative shadow-[0_-10px_20px_rgba(0,0,0,0.1)] overflow-hidden"
        role="region"
        aria-label="手札"
      >
        <div class="absolute -top-4 md:-top-6 left-1/2 transform -translate-x-1/2 bg-shu text-washi px-4 md:px-6 py-1 rounded-t-lg font-bold shadow-md border-x-2 border-t-2 border-sumi text-xs md:text-base z-10">
          手札
        </div>
        <div
          class="h-full w-full flex items-center justify-start md:justify-center gap-2 md:gap-4 px-4 md:px-8 overflow-x-auto scrollbar-thin scrollbar-thumb-sumi scrollbar-track-transparent pb-2"
          role="group"
          aria-label="手札カード"
        >
          <.ofuda_card
            :for={card <- @hand_cards}
            id={card.id}
            title={card.title}
            cost={card.cost}
            type={card.type}
            phx-click="select_card"
            phx-dblclick="use_card"
            phx-value-card-id={card.id}
            class={
              [
                "hover:z-10 w-16 h-24 md:w-24 md:h-36",
                if(@selected_card_id == card.id,
                  do: "ring-4 ring-shu/50 border-shu scale-105",
                  else: ""
                ),
                if(@game_state.currency < card.cost,
                  do: "opacity-50 cursor-not-allowed",
                  else: "cursor-pointer"
                )
              ]
              |> Enum.filter(&(&1 != ""))
              |> Enum.join(" ")
            }
            aria-disabled={@game_state.currency < card.cost}
          />
        </div>
      </div>
    </div>

    <!-- Toast notifications -->
    <div class="fixed top-4 right-4 z-50 space-y-2">
      <.toast
        :for={toast <- @toasts}
        id={toast.id}
        kind={toast.kind}
        message={toast.message}
        phx-hook="ToastAutoRemove"
      />
    </div>
    """
  end

  # Event handlers
  def handle_event("validate_chat", %{"chat" => params}, socket) do
    {:noreply, assign(socket, :chat_form, chat_form(params))}
  end

  def handle_event("send_chat", %{"chat" => params}, socket) do
    trimmed = params["body"] |> to_string() |> String.trim()
    author = params["author"] |> presence_or("anonymous")

    if trimmed == "" do
      {:noreply,
       assign(socket, :chat_form, chat_form(params, errors: [body: {"内容を入力してください", []}]))}
    else
      # Create message via rogs_comm Messages context
      case create_message(socket.assigns.room_id, trimmed, socket.assigns.user_id, author) do
        {:ok, _message} ->
          # Message will be broadcast via PubSub and handled in handle_info
          {:noreply, assign(socket, :chat_form, chat_form())}

        {:error, _changeset} ->
          # Show error toast and fallback: add message locally if rogs_comm is not available
          toast_id = "toast-#{System.unique_integer([:positive])}"
          new_toast = %{id: toast_id, kind: :error, message: "メッセージの送信に失敗しました。再試行してください。"}

          new_msg = %{
            id: Ecto.UUID.generate(),
            user_email: author,
            content: trimmed,
            inserted_at: DateTime.utc_now()
          }

          socket =
            socket
            |> stream(:chat_messages, [new_msg])
            |> assign(:chat_form, chat_form())
            |> update(:toasts, fn toasts -> [new_toast | toasts] end)

          # Auto-remove toast after 5 seconds
          Process.send_after(self(), {:remove_toast, toast_id}, 5000)

          {:noreply, socket}
      end
    end
  end

  def handle_event("select_card", %{"card-id" => card_id}, socket) do
    selected = if socket.assigns.selected_card_id == card_id, do: nil, else: card_id
    {:noreply, assign(socket, :selected_card_id, selected)}
  end

  def handle_event("use_card", %{"card-id" => card_id}, socket) do
    card = Enum.find(socket.assigns.hand_cards, &(&1.id == card_id))

    if card && socket.assigns.game_state.currency >= card.cost do
      # TODO: Implement actual card usage logic when backend is ready
      toast_id = "toast-#{System.unique_integer([:positive])}"

      new_toast = %{
        id: toast_id,
        kind: :success,
        message: "カード「#{card.title}」を使用しました。"
      }

      socket =
        socket
        |> assign(:selected_card_id, nil)
        |> update(:toasts, fn toasts -> [new_toast | toasts] end)

      # Auto-remove toast after 3 seconds
      Process.send_after(self(), {:remove_toast, toast_id}, 3000)

      {:noreply, socket}
    else
      toast_id = "toast-#{System.unique_integer([:positive])}"

      new_toast = %{
        id: toast_id,
        kind: :error,
        message: "空環が不足しています。"
      }

      socket =
        socket
        |> update(:toasts, fn toasts -> [new_toast | toasts] end)

      Process.send_after(self(), {:remove_toast, toast_id}, 3000)

      {:noreply, socket}
    end
  end

  def handle_event("execute_action", %{"action" => action}, socket) do
    # TODO: Implement actual action logic when backend is ready
    toast_id = "toast-#{System.unique_integer([:positive])}"

    new_toast = %{
      id: toast_id,
      kind: :info,
      message: "アクション「#{action}」を実行しました。"
    }

    socket =
      socket
      |> update(:toasts, fn toasts -> [new_toast | toasts] end)

    # Auto-remove toast after 3 seconds
    Process.send_after(self(), {:remove_toast, toast_id}, 3000)

    {:noreply, socket}
  end

  # Info handlers
  def handle_info(%Phoenix.Socket.Broadcast{event: "new_message", payload: payload}, socket) do
    message = %{
      id: payload.id || Ecto.UUID.generate(),
      user_email: payload.user_email || "anonymous",
      content: payload.content,
      inserted_at: payload.inserted_at || DateTime.utc_now()
    }

    {:noreply, stream(socket, :chat_messages, [message])}
  end

  def handle_info({:remove_toast, toast_id}, socket) do
    {:noreply,
     update(socket, :toasts, fn toasts -> Enum.reject(toasts, &(&1.id == toast_id)) end)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp life_index(state), do: state.forest + state.culture + state.social

  defp gauge_width(value, max \\ 20) do
    value
    |> max(0)
    |> min(max)
    |> Kernel./(max)
    |> Kernel.*(100)
    |> Float.round(1)
  end

  defp chat_form(params \\ %{"author" => "You", "body" => ""}, opts \\ []) do
    defaults = %{"author" => "You", "body" => ""}

    params =
      defaults
      |> Map.merge(params)
      |> Map.update!("body", &to_string/1)

    to_form(params, Keyword.merge([as: :chat], opts))
  end

  defp presence_or(nil, fallback), do: fallback
  defp presence_or("", fallback), do: fallback
  defp presence_or(value, _fallback), do: value

  defp mock_game_state do
    %{
      room: "SHU-104",
      turn: 8,
      max_turns: 20,
      forest: 15,
      culture: 10,
      social: 10,
      currency: 128,
      demurrage: -12,
      life_index_target: 40
    }
  end

  # Load messages from rogs_comm Messages context
  defp load_messages(room_id) do
    case Code.ensure_loaded(Messages) do
      {:module, _} ->
        if function_exported?(Messages, :list_messages, 2) do
          try do
            Messages.list_messages(room_id, limit: 50)
            |> Enum.map(fn msg ->
              %{
                id: msg.id,
                user_email: msg.user_email,
                content: msg.content,
                inserted_at: msg.inserted_at
              }
            end)
          rescue
            _ -> []
          end
        else
          []
        end

      {:error, _} ->
        # Fallback to empty list if rogs_comm Messages is not available
        []
    end
  end

  # Create message via rogs_comm Messages context
  defp create_message(room_id, content, user_id, user_email) do
    case Code.ensure_loaded(Messages) do
      {:module, _} ->
        if function_exported?(Messages, :create_message, 1) do
          try do
            Messages.create_message(%{
              content: content,
              room_id: room_id,
              user_id: user_id,
              user_email: user_email
            })
          rescue
            _ -> {:error, :unavailable}
          end
        else
          {:error, :unavailable}
        end

      {:error, _} ->
        {:error, :unavailable}
    end
  end

  def format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M")
  def format_time(str) when is_binary(str), do: str
  def format_time(_), do: ""

  defp circumference, do: 2 * :math.pi() * 90

  defp circumference_offset(current, target) when target > 0 do
    progress = min(current / target, 1.0)
    circumference() * (1 - progress)
  end

  defp circumference_offset(_, _), do: circumference()

  defp mock_hand_cards do
    [
      %{id: "c1", title: "植林", type: :action, cost: 3},
      %{id: "c2", title: "祭事", type: :event, cost: 5},
      %{id: "c3", title: "交流", type: :reaction, cost: 2},
      %{id: "c4", title: "開発", type: :action, cost: 8}
    ]
  end

  defp mock_actions do
    [
      %{label: "投資", color: "shu", action: "invest"},
      %{label: "伐採", color: "matsu", action: "harvest"},
      %{label: "寄付", color: "sumi", action: "donate"}
    ]
  end
end
