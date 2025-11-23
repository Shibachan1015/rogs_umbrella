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
        <aside class="w-80 bg-washi-dark border-r-2 border-sumi flex flex-col z-20 shadow-lg">
          <div class="p-4 border-b-2 border-sumi text-center space-y-1">
            <div class="text-[10px] uppercase tracking-[0.6em] text-sumi/60">Room</div>
            <div class="text-2xl font-bold tracking-[0.5em] text-shu">{@game_state.room}</div>
            <div class="text-xs text-sumi/60">Turn {@game_state.turn} / {@game_state.max_turns}</div>
          </div>

          <div class="grid grid-cols-2 gap-3 px-4 py-3 border-b-2 border-sumi text-xs">
            <div class="bg-washi p-3 rounded shadow-inner border border-sumi/20">
              <div class="uppercase tracking-[0.3em] text-sumi/50 mb-1">Currency</div>
              <div class="text-lg font-semibold text-kin">{@game_state.currency}</div>
            </div>
            <div class="bg-washi p-3 rounded shadow-inner border border-sumi/20">
              <div class="uppercase tracking-[0.3em] text-sumi/50 mb-1">Demurrage</div>
              <div class="text-lg font-semibold text-sumi">{@game_state.demurrage}</div>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto p-4 space-y-3 scrollbar-thin scrollbar-thumb-sumi scrollbar-track-transparent">
            <div class="text-[10px] uppercase tracking-[0.5em] text-sumi/50">Chat Log</div>
            <div id="chat-messages" phx-update="stream" class="space-y-3">
              <div
                :for={{id, msg} <- @streams.chat_messages}
                id={id}
                class="border border-sumi/15 rounded-lg bg-washi p-3 shadow-sm"
              >
                <div class="flex justify-between text-[10px] uppercase tracking-[0.4em] text-sumi/50">
                  <span>{msg.user_email || msg.author}</span>
                  <span>{format_time(msg.inserted_at || msg.sent_at)}</span>
                </div>
                <p class="text-sm text-sumi mt-2 leading-relaxed">{msg.content || msg.body}</p>
              </div>
            </div>
          </div>

          <div class="border-t-2 border-sumi bg-washi-dark/70 p-4 space-y-3">
            <div class="uppercase tracking-[0.4em] text-[10px] text-sumi/50">Send Message</div>
            <.form
              for={@chat_form}
              id="chat-form"
              phx-submit="send_chat"
              phx-change="validate_chat"
              class="space-y-3"
            >
              <.input
                field={@chat_form[:body]}
                type="textarea"
                placeholder="想いを紡ぐ..."
                class="bg-washi border border-sumi/20 focus:border-shu focus:ring-0 min-h-20 text-sm"
              />

              <div class="flex items-center gap-2">
                <.input
                  field={@chat_form[:author]}
                  type="text"
                  class="bg-washi border border-sumi/20 focus:border-sumi focus:ring-0 text-xs uppercase tracking-[0.4em]"
                  placeholder="署名"
                />
                <button
                  type="submit"
                  class="ml-auto px-4 py-2 bg-shu text-washi rounded-full text-xs tracking-[0.3em] hover:bg-shu/90 transition shadow"
                  phx-disable-with="送信中..."
                >
                  送信
                </button>
              </div>
            </.form>
          </div>
        </aside>

        <!-- Main Board -->
        <main class="flex-1 relative overflow-hidden flex items-center justify-center p-8">
          <div class="relative w-[800px] h-[800px] bg-washi rounded-full border-4 border-sumi flex items-center justify-center shadow-xl">
            <!-- Life Index Circle -->
            <div class="absolute inset-0 m-auto w-[600px] h-[600px] rounded-full border-2 border-sumi/20 flex items-center justify-center">
              <div class="text-center">
                <div class="text-2xl uppercase tracking-[0.4em] text-sumi/60">Life Index</div>
                <div class="text-7xl font-bold text-shu font-serif mb-2">{life_index(@game_state)}</div>
                <div class="text-xs text-sumi/50 uppercase tracking-[0.5em]">
                  Target {@game_state.life_index_target} / Turn {@game_state.turn} of {@game_state.max_turns}
                </div>
              </div>
            </div>

            <!-- Gauges -->
            <div class="absolute top-10 left-1/2 -translate-x-1/2 flex flex-col items-center drop-shadow-sm">
               <span class="text-matsu font-bold text-xl">Forest (F)</span>
               <div class="w-40 h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi">
                 <div class="h-full bg-matsu transition-all duration-500" style={"width: #{gauge_width(@game_state.forest)}%"}></div>
               </div>
               <span class="text-sm">{@game_state.forest}</span>
            </div>

            <div class="absolute bottom-20 left-20 flex flex-col items-center drop-shadow-sm">
               <span class="text-sakura font-bold text-xl">Culture (K)</span>
               <div class="w-32 h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi">
                 <div class="h-full bg-sakura transition-all duration-500" style={"width: #{gauge_width(@game_state.culture)}%"}></div>
               </div>
               <span class="text-sm">{@game_state.culture}</span>
            </div>

            <div class="absolute bottom-20 right-20 flex flex-col items-center drop-shadow-sm">
               <span class="text-kohaku font-bold text-xl">Social (S)</span>
               <div class="w-32 h-4 bg-sumi/10 rounded-full overflow-hidden mt-1 border border-sumi">
                 <div class="h-full bg-kohaku transition-all duration-500" style={"width: #{gauge_width(@game_state.social)}%"}></div>
               </div>
               <span class="text-sm">{@game_state.social}</span>
            </div>
          </div>

          <!-- Actions (Stamps) -->
          <div class="absolute bottom-8 right-8 flex gap-4">
            <.hanko_btn
              :for={button <- @action_buttons}
              label={button.label}
              color={button.color}
              class="shadow-lg hover:-translate-y-1 transition"
            />
          </div>
        </main>
      </div>

      <!-- Bottom Hand -->
      <div class="h-48 bg-washi-dark border-t-4 border-sumi z-30 relative shadow-[0_-10px_20px_rgba(0,0,0,0.1)]">
        <div class="absolute -top-6 left-1/2 transform -translate-x-1/2 bg-shu text-washi px-6 py-1 rounded-t-lg font-bold shadow-md border-x-2 border-t-2 border-sumi">
          手札
        </div>
        <div class="h-full w-full flex items-center justify-center gap-4 px-8 overflow-x-auto">
           <.ofuda_card
             :for={card <- @hand_cards}
             id={card.id}
             title={card.title}
             cost={card.cost}
             type={card.type}
           />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate_chat", %{"chat" => params}, socket) do
    {:noreply, assign(socket, :chat_form, chat_form(params))}
  end

  def handle_event("send_chat", %{"chat" => params}, socket) do
    trimmed = params["body"] |> to_string() |> String.trim()
    author = params["author"] |> presence_or("anonymous")

    if trimmed == "" do
      {:noreply, assign(socket, :chat_form, chat_form(params, errors: [body: {"内容を入力してください", []}]))}
    else
      # Create message via rogs_comm Messages context
      case create_message(socket.assigns.room_id, trimmed, socket.assigns.user_id, author) do
        {:ok, _message} ->
          # Message will be broadcast via PubSub and handled in handle_info
          {:noreply, assign(socket, :chat_form, chat_form())}

        {:error, _changeset} ->
          # Fallback: add message locally if rogs_comm is not available
          new_msg = %{
            id: Ecto.UUID.generate(),
            user_email: author,
            content: trimmed,
            inserted_at: DateTime.utc_now()
          }

          {:noreply,
           socket
           |> stream(:chat_messages, [new_msg])
           |> assign(:chat_form, chat_form())}
      end
    end
  end

  # Handle real-time chat messages from rogs_comm PubSub
  def handle_info(%Phoenix.Socket.Broadcast{event: "new_message", payload: payload}, socket) do
    message = %{
      id: payload.id || Ecto.UUID.generate(),
      user_email: payload.user_email || "anonymous",
      content: payload.content,
      inserted_at: payload.inserted_at || DateTime.utc_now()
    }

    {:noreply, stream(socket, :chat_messages, [message])}
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
      %{label: "投資", color: "shu"},
      %{label: "伐採", color: "matsu"},
      %{label: "寄付", color: "sumi"}
    ]
  end
end
