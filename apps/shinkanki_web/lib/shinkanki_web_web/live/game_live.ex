defmodule ShinkankiWebWeb.GameLive do
  use ShinkankiWebWeb, :live_view

  alias RogsComm.PubSub, as: CommPubSub
  alias RogsComm.Messages
  alias RogsComm.Rooms
  alias Shinkanki
  alias Shinkanki.Games

  def mount(params, _session, socket) do
    # Get slug from params (route is /game/:room_id but actually receives slug)
    slug = params["room_id"]

    if slug == nil do
      {:ok,
       socket
       |> put_flash(:error, "ルームIDが指定されていません")
       |> push_navigate(to: ~p"/lobby")}
    else
      # Get user info from session (from rogs_identity)
      current_user = socket.assigns[:current_user]

      if current_user == nil do
        {:ok,
         socket
         |> put_flash(:error, "ログインしてください")
         |> push_navigate(to: ~p"/users/log-in")}
      else
        # First, find the room by slug to get the actual room_id (UUID)
        case Rooms.fetch_room_by_slug(slug) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "ルームが見つかりません")
             |> push_navigate(to: ~p"/lobby")}

          room ->
            user_id = current_user.id
            user_email = current_user.email || "anonymous"
            room_id = room.id

            # DBからゲームセッションを取得
            game_session = Games.get_game_session_by_room_id(room_id)

            if game_session == nil do
              {:ok,
               socket
               |> put_flash(:error, "ゲームセッションが見つかりません")
               |> push_navigate(to: ~p"/lobby")}
            else
              # ゲーム状態をフォーマット
              game_state = format_game_session(game_session, user_id)

              mount_with_game_session(socket, room_id, user_id, user_email, current_user, game_session, game_state)
            end
        end
      end
    end
  end

  defp mount_with_game_session(socket, room_id, user_id, user_email, current_user, game_session, game_state) do
    # 現在のターン状態を取得
    turn_state = get_current_turn_state(game_session)
    current_phase = if turn_state, do: turn_state.phase, else: "event"

    socket =
      socket
      |> assign(:game_session, game_session)
      |> assign(:game_state, game_state)
      |> assign(:room_id, room_id)
      |> assign(:user_id, user_id)
      |> assign(:user_email, user_email)
      |> assign(:current_user, current_user)
      |> assign(:current_scope, nil)
      |> assign(:player_name, user_email)
      |> assign(:hand_cards, get_hand_cards_from_session(game_session, turn_state))
      |> assign(:action_buttons, get_available_action_cards(game_session, turn_state))
      |> assign(:chat_form, chat_form())
      |> assign(:toasts, [])
      |> assign(:selected_card_id, nil)
      |> assign(:current_phase, current_phase)
      |> assign(:current_event, get_current_event(game_session, turn_state))
      |> assign(:show_event_modal, false)
      |> assign(:player_talents, get_player_talents_from_session(game_session, user_id))
      |> assign(:selected_talents_for_card, [])
      |> assign(:show_talent_selector, false)
      |> assign(:talent_selector_card_id, nil)
      |> assign(:active_projects, get_active_projects_from_session(game_session))
      |> assign(:show_project_contribute, false)
      |> assign(:project_contribute_id, nil)
      |> assign(:selected_talent_for_contribution, nil)
      |> assign(:show_action_confirm, false)
      |> assign(:confirm_card_id, nil)
      |> assign(:show_ending, game_session.status in ["completed", "failed"])
      |> assign(:game_status, game_session.status)
      |> assign(:ending_type, get_ending_type(game_session))
      |> assign(:show_role_selection, false)
      |> assign(:selected_role, nil)
      |> assign(:player_role, get_player_role(game_session, user_id))
      |> assign(:players, get_players_from_session(game_session))
      |> assign(:show_demurrage, false)
      |> assign(:previous_currency, 0)
      |> assign(:show_card_detail, false)
      |> assign(:detail_card, nil)
      |> assign(:can_start, false) # ゲームは既に開始されている

    socket =
      if connected?(socket) do
        # Subscribe to rogs_comm PubSub for real-time chat updates
        chat_topic = "room:#{room_id}"
        Phoenix.PubSub.subscribe(CommPubSub, chat_topic)

        # Subscribe to GamePubSub for game state updates
        Shinkanki.GamePubSub.subscribe(game_session.id)

        # Load initial messages from rogs_comm
        messages = load_messages(room_id)
        stream(socket, :chat_messages, messages, reset: true)
      else
        stream(socket, :chat_messages, [], reset: true)
      end

    {:ok, socket, layout: {ShinkankiWebWeb.Layouts, :game}}
  end

  # ゲームセッションをフォーマット
  defp format_game_session(game_session, user_id) do
    # プレイヤーのAkashaを取得（現在のユーザー）
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)
    currency = if player, do: player.akasha, else: 0

    %{
      id: game_session.id,
      room: game_session.room_id || "UNKNOWN",
      room_id: game_session.room_id,
      turn: game_session.turn,
      max_turns: 20,
      forest: game_session.forest,
      culture: game_session.culture,
      social: game_session.social,
      life_index: game_session.life_index,
      life_index_target: 40,
      dao_pool: game_session.dao_pool,
      currency: currency,
      demurrage: calculate_demurrage_amount(currency),
      status: game_session.status,
      players: get_players_from_session(game_session),
      current_user_id: user_id
    }
  end

  # 現在のターン状態を取得
  defp get_current_turn_state(game_session) do
    game_session.turn_states
    |> Enum.find(fn ts -> ts.turn_number == game_session.turn end)
  end

  # 利用可能なアクションカードを取得
  defp get_available_action_cards(_game_session, turn_state) do
    if turn_state && turn_state.available_cards do
      Shinkanki.Games.ActionCard
      |> Shinkanki.Repo.all()
      |> Enum.filter(fn card -> card.id in turn_state.available_cards end)
      |> Enum.map(fn card ->
        # カテゴリに応じた色を設定
        color = case card.category do
          "forest" -> "matsu"
          "culture" -> "sakura"
          "social" -> "kohaku"
          "akasha" -> "kin"
          _ -> "sumi"
        end

        %{
          id: card.id,
          name: card.name,
          label: card.name,
          category: card.category,
          description: card.description,
          cost_forest: card.cost_forest,
          cost_culture: card.cost_culture,
          cost_social: card.cost_social,
          cost_akasha: card.cost_akasha,
          color: color,
          action: "play_action_card"
        }
      end)
    else
      []
    end
  end

  # 現在のイベントカードを取得
  defp get_current_event(_game_session, turn_state) do
    if turn_state && turn_state.current_event_id do
      event = Shinkanki.Repo.get!(Shinkanki.Games.EventCard, turn_state.current_event_id)
      %{
        id: event.id,
        name: event.name,
        description: event.description,
        has_choice: event.has_choice,
        choice_a_text: event.choice_a_text,
        choice_b_text: event.choice_b_text
      }
    else
      nil
    end
  end

  # アクティブなプロジェクトを取得
  defp get_active_projects_from_session(game_session) do
    game_session.game_projects
    |> Enum.filter(fn project -> project.status == "active" end)
    |> Enum.map(fn project ->
      template = project.project_template
      # current_progress is not in DB schema, calculate from participations
      progress = length(project.project_participations || [])
      %{
        id: project.id,
        name: template.name,
        description: template.description,
        progress: progress,
        required_participants: template.required_participants,
        required_turns: template.required_turns,
        required_dao_pool: template.required_dao_pool
      }
    end)
  end

  # エンディングタイプを取得
  defp get_ending_type(game_session) do
    if game_session.status == "completed" do
      Shinkanki.Games.GameSession.get_ending(game_session)
    else
      nil
    end
  end

  # プレイヤーの役割を取得
  defp get_player_role(game_session, user_id) do
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)
    if player, do: player.role, else: nil
  end

  # プレイヤーリストを取得
  defp get_players_from_session(game_session) do
    game_session.players
    |> Enum.sort_by(& &1.player_order)
    |> Enum.map(fn player ->
      %{
        id: player.id,
        user_id: player.user_id,
        name: if(player.is_ai, do: player.ai_name, else: "Player"),
        avatar: "🎮",
        role: player.role,
        akasha: player.akasha,
        is_ai: player.is_ai,
        # is_ready is not in DB schema, use Map.get for safety
        is_ready: Map.get(player, :is_ready, false)
      }
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="landing-body min-h-screen flex flex-col text-[var(--color-landing-text-primary)]">
      <div class="torii-lines pointer-events-none hidden lg:block"></div>
      <div class="flex-1 flex overflow-hidden relative landing-container px-0">
        <!-- Sidebar -->
        <aside
          class="fixed lg:static inset-y-0 left-0 w-72 sm:w-80 bg-[rgba(15,20,25,0.9)] border-r border-[var(--color-landing-gold)]/15 text-[var(--color-landing-text-primary)] flex flex-col z-20 shadow-[0_20px_60px_rgba(0,0,0,0.45)] backdrop-blur-xl lg:translate-x-0 -translate-x-full transition-transform duration-300"
          id="sidebar"
          role="complementary"
          aria-label="ゲーム情報とチャット"
          aria-hidden="false"
        >
          <button
            class="lg:hidden fixed left-0 top-4 z-30 w-10 h-10 bg-shu text-washi rounded-r-lg flex items-center justify-center shadow-md"
            phx-click={JS.toggle_class("translate-x-0 -translate-x-full", to: "#sidebar")}
            aria-label="サイドバーを開く"
            aria-expanded="false"
            id="sidebar-toggle"
          >
            <.icon name="hero-bars-3" class="w-5 h-5" />
          </button>
          <button
            class="lg:hidden absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30"
            phx-click={JS.toggle_class("translate-x-0 -translate-x-full", to: "#sidebar")}
            aria-label="サイドバーを閉じる"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>

          <div class="hud-panel text-center space-y-4 mb-4">
            <div class="hud-section-title" aria-label="ルーム名">Room</div>
            <div
              class="text-2xl font-bold tracking-[0.45em] text-[var(--color-landing-gold)] drop-shadow"
              aria-label={"ルーム: #{@game_state[:room_id] || @game_state.room_id || "UNKNOWN"}"}
            >
              {@game_state[:room_id] || @game_state.room_id || "UNKNOWN"}
            </div>
            <div class="hud-panel-divider" aria-hidden="true"></div>
            <div class="w-full space-y-3">
              <% max_turns = 20
              remaining_turns = max(0, max_turns - (@game_state[:turn] || @game_state.turn || 1))
              progress_percentage = trunc((@game_state[:turn] || @game_state.turn || 1) / max_turns * 100)
              is_warning = remaining_turns <= 5
              is_critical = remaining_turns <= 3
              demurrage_value = 0 %>
              <div class="flex justify-between items-baseline text-[var(--color-landing-text-secondary)]">
                <span class="text-xs uppercase tracking-[0.3em]" aria-label="ターン: {@game_state.turn} / {@game_state.max_turns}">
                  Turn {@game_state.turn} / {@game_state.max_turns}
                </span>
                <span class="text-[10px]">
                  ({progress_percentage}%)
                </span>
                <div class={["flex items-baseline gap-1", if(is_critical, do: "turn-remaining-warning", else: "")]}>
                  <span class={[
                    "text-lg sm:text-xl font-bold font-serif",
                    if(is_critical,
                      do: "text-shu",
                      else: if(is_warning, do: "text-kohaku", else: "text-matsu")
                    )
                  ]}>
                    {remaining_turns}
                  </span>
                  <span class={[
                    "text-xs font-semibold",
                    if(is_critical,
                      do: "text-shu",
                      else: if(is_warning, do: "text-kohaku", else: "text-sumi/60")
                    )
                  ]}>
                    ターン残り
                  </span>
                </div>
              </div>
              <div class={[
                "w-full h-3 rounded-full overflow-hidden border",
                if(is_critical,
                  do: "border-shu/40 turn-progress-glow bg-shu/10",
                  else:
                    if(is_warning,
                      do: "border-kohaku/40 bg-kohaku/10",
                      else: "border-[var(--color-landing-gold)]/20 bg-white/5"
                    )
                )
              ]}>
                <div class="turn-progress-bar h-full">
                  <div
                    class={[
                      "h-full transition-all duration-700 ease-out rounded-full",
                      if(is_critical,
                        do: "bg-gradient-to-r from-shu to-shu/80",
                        else:
                          if(is_warning,
                            do: "bg-gradient-to-r from-kohaku to-kohaku/80",
                            else: "bg-gradient-to-r from-matsu to-matsu/80"
                          )
                      )
                    ]}
                    style={"width: #{progress_percentage}%"}
                    role="progressbar"
                    aria-valuenow={@game_state.turn}
                    aria-valuemin="1"
                    aria-valuemax={@game_state.max_turns}
                    aria-label={"ターン進行: #{@game_state.turn}/#{@game_state.max_turns} (#{progress_percentage}%)"}
                  >
                  </div>
                </div>
              </div>
              <%= if is_critical do %>
                <div class="text-center">
                  <span class="text-xs font-semibold text-shu animate-pulse">
                    ⚠ 残りターンが少なくなっています
                  </span>
                </div>
              <% else %>
                <%= if is_warning do %>
                  <div class="text-center">
                    <span class="text-xs text-kohaku">
                      残りターンに注意
                    </span>
                  </div>
                <% end %>
              <% end %>
            </div>
            <div class="hud-info-grid mt-4 text-left">
              <div class="hud-info-card">
                <span class="hud-info-card-label">AKASHA</span>
                <span class="hud-info-card-value">{@game_state[:currency] || @game_state.currency || 0}</span>
                <span class="hud-info-card-subtle">空環ポイント</span>
              </div>
              <div class="hud-info-card">
                <span class="hud-info-card-label">DEMURRAGE</span>
                <span class="hud-info-card-value">{demurrage_value}</span>
                <span class="hud-info-card-subtle">減衰量</span>
                <span class="hud-info-card-diff">
                  <%= if demurrage_value >= 0, do: "+", else: "-" %>{abs(demurrage_value)}
                </span>
              </div>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto px-3 sm:px-4 space-y-4 pb-6 sidebar-scroll">
            <div class="hud-panel-light">
              <.phase_indicator current_phase={@current_phase} />
            </div>

            <%= if @current_phase == :discussion && @game_status == :playing do %>
              <div class="hud-panel-light text-center space-y-2">
                <div class="text-xs text-[var(--color-landing-text-secondary)]">
                  相談フェーズ - 準備ができたらボタンを押してください
                </div>
                <%= if get_player_ready_status(@players, @user_id) do %>
                  <div class="text-xs text-matsu font-semibold">
                    ✓ 準備完了
                  </div>
                <% else %>
                  <button
                    class="cta-button cta-outline w-full justify-center tracking-[0.3em]"
                    phx-click="execute_action"
                    phx-value-action="mark_discussion_ready"
                    aria-label="準備完了"
                  >
                    準備完了
                  </button>
                <% end %>
              </div>
            <% end %>

            <%= if @current_phase == :action && @game_status == :playing do %>
              <div class="hud-panel-light text-center space-y-2">
                <div class="hud-section-title">現在のターン</div>
                <div class="text-sm font-bold text-[var(--color-landing-pale)]">
                  {get_current_player_name(@game_state, @players) || "プレイヤー"}
                </div>
                <%= if is_current_player_turn(@game_state, @user_id) do %>
                  <div class="text-xs text-matsu font-semibold">
                    ← あなたのターンです
                  </div>
                <% end %>
              </div>
            <% end %>

            <%= if @game_status == :waiting do %>
              <div class="hud-panel-light space-y-3">
                <div class="space-y-2">
                  <div class="hud-section-title text-center">
                    参加プレイヤー
                  </div>
                  <div class="space-y-1 max-h-32 overflow-y-auto">
                    <%= for player <- @players do %>
                      <% player_id = player[:id] || player["id"] || player.id %>
                      <div class="text-xs text-[var(--color-landing-text-secondary)] px-2 py-1 bg-white/5 rounded border border-white/10">
                        <span class="font-semibold text-[var(--color-landing-pale)]">
                          {player[:name] || player["name"] || player.name || "Player"}
                        </span>
                        <%= if player_id == @user_id do %>
                          <span class="text-[var(--color-landing-text-secondary)] ml-1">(あなた)</span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                  <div class="text-xs text-[var(--color-landing-text-secondary)] text-center">
                    {length(@players)} / 4 プレイヤー
                  </div>
                </div>
                <div class="pt-2 border-t border-white/10">
                  <%= if @can_start do %>
                    <button
                      class="cta-button cta-solid w-full justify-center tracking-[0.3em] disabled:opacity-50 disabled:cursor-not-allowed"
                      phx-click="execute_action"
                      phx-value-action="start_game"
                      aria-label="ゲームを開始"
                    >
                      ゲームを開始
                    </button>
                  <% else %>
                    <div class="text-xs text-[var(--color-landing-text-secondary)] text-center py-2">
                      最小プレイヤー数（1人）に達していません
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <div class="hud-panel-light">
              <div class="hud-section-title mb-2">プレイヤー</div>
              <div class="space-y-2">
                <.player_info_card
                  :for={player <- @players}
                  player_id={player[:id] || player["id"]}
                  player_name={player[:name] || player["name"] || "プレイヤー"}
                  role={player[:role] || player["role"]}
                  is_current_player={(player[:id] || player["id"]) == @user_id}
                  is_ready={player[:is_ready] || player["is_ready"] || false}
                  is_current_turn={is_current_player_turn(@game_state, player[:id] || player["id"])}
                  class="w-full"
                />
              </div>
            </div>

            <div
              class="hud-panel hud-chat-card p-4 space-y-3 scrollbar-thin scrollbar-thumb-sumi scrollbar-track-transparent"
              id="chat-container"
              phx-hook="ChatScroll"
              role="log"
              aria-label="チャットログ"
              aria-live="polite"
              aria-atomic="false"
            >
              <div class="hud-section-title">Chat Log</div>
              <div id="chat-messages" phx-update="stream" class="space-y-3">
                <div
                  :for={{id, msg} <- @streams.chat_messages}
                  id={id}
                  class="chat-message border border-white/10 rounded-lg bg-white/5 p-3 shadow-sm"
                  phx-mounted={
                    JS.add_class("new-message", to: "##{id}")
                    |> JS.remove_class("new-message", time: 2000, to: "##{id}")
                  }
                  role="article"
                  aria-label={"メッセージ from #{msg.user_email || msg.author}"}
                >
                  <div class="flex justify-between text-[10px] uppercase tracking-[0.4em] text-[var(--color-landing-text-secondary)]">
                    <span class="font-semibold text-[var(--color-landing-pale)]" aria-label="送信者">
                      {msg.user_email || msg.author}
                    </span>
                    <time
                      class="text-[var(--color-landing-text-secondary)]"
                      datetime={if msg.inserted_at, do: DateTime.to_iso8601(msg.inserted_at), else: ""}
                      aria-label="送信時刻"
                    >
                      {format_time(msg.inserted_at || msg.sent_at)}
                    </time>
                  </div>
                  <p class="text-sm text-[var(--color-landing-text-primary)] mt-2 leading-relaxed">
                    {msg.content || msg.body}
                  </p>
                </div>
              </div>
            </div>

            <div class="hud-panel-light space-y-3" role="region" aria-label="メッセージ送信">
              <div class="hud-section-title">Send Message</div>
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
                  class="hud-chat-input min-h-20 text-sm"
                  phx-hook="ChatInput"
                  autofocus
                  aria-label="メッセージ本文"
                  aria-describedby="chat-body-help"
                />
                <p id="chat-body-help" class="sr-only">
                  メッセージを入力してください。Enterキーで送信、Shift+Enterで改行します。
                </p>
                <div class="flex items-center gap-2">
                  <.input
                    field={@chat_form[:author]}
                    type="text"
                    class="hud-chat-input text-xs uppercase tracking-[0.3em]"
                    placeholder="署名"
                    aria-label="送信者名"
                  />
                  <button
                    type="submit"
                    class="cta-button cta-solid h-10 px-4 flex items-center gap-2 tracking-[0.3em] disabled:opacity-50 disabled:cursor-not-allowed"
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
          </div>
        </aside>

    <!-- Main Board -->
        <main
          class="flex-1 relative overflow-hidden flex flex-col items-center p-4 sm:p-8 md:p-10 lg:ml-0 resonance-shell"
          role="main"
          aria-label="ゲームボード"
        >
          <div class="resonance-board w-full max-w-6xl flex flex-col items-center gap-8 p-4 sm:p-8 md:p-10">
          <!-- Phase Indicator (Top of Main Board) -->
          <%= if @game_status == :playing do %>
            <div class="w-full max-w-4xl mb-4 sm:mb-6 animate-fade-in">
              <.phase_indicator current_phase={@current_phase} />
            </div>
          <% end %>

    <!-- Event Card Display (Event Phase) -->
          <%= if @current_phase == :event && @current_event do %>
            <div class="w-full max-w-md mx-auto animate-fade-in hud-panel text-[var(--color-landing-text-primary)]">
              <div class="hud-section-title mb-3 text-center">現在のイベント</div>
              <.event_card
                title={@current_event[:title] || @current_event["title"] || "イベント"}
                description={@current_event[:description] || @current_event["description"] || ""}
                effect={@current_event[:effect] || @current_event["effect"] || %{}}
                category={@current_event[:category] || @current_event["category"] || :neutral}
                phx-click="show_event_modal"
                class="cursor-pointer hover:scale-105 transition-transform"
              />
            </div>
          <% else %>
            <!-- Active Projects Display -->
            <%= if length(@active_projects) > 0 && @game_status == :playing do %>
              <section class="project-stage" aria-label="共創プロジェクト">
                <div class="project-stage-header">
                  <div>
                    <p class="stage-label">共創プロジェクト</p>
                    <p class="stage-subtitle">才能を捧げ、森と文化とつながりを再構築</p>
                  </div>
                  <div class="project-metrics">
                    <div class="project-metric">
                      <span class="metric-label">ACTIVE</span>
                      <span class="metric-value">{length(@active_projects)}</span>
                    </div>
                    <div class="project-metric">
                      <span class="metric-label">AKASHA φ</span>
                      <span class="metric-value">{@game_state[:currency] || @game_state.currency || 0}</span>
                    </div>
                  </div>
                </div>
                <div class="project-grid">
                  <%= for project <- @active_projects do %>
                    <div
                      class="cursor-pointer transition-transform"
                      phx-click="open_project_contribute"
                      phx-value-project-id={project[:id] || project["id"]}
                    >
                      <.project_card
                        title={project[:name] || project["name"] || "プロジェクト"}
                        description={project[:description] || project["description"] || ""}
                        cost={
                          project[:required_progress] || project["required_progress"] ||
                            project[:cost] || 0
                        }
                        progress={project[:progress] || project["progress"] || 0}
                        effect={project[:effect] || project["effect"] || %{}}
                        unlock_condition={
                          project[:unlock_condition] || project["unlock_condition"] || %{}
                        }
                        is_unlocked={project[:is_unlocked] || project["is_unlocked"] || true}
                        is_completed={project[:is_completed] || project["is_completed"] || false}
                        contributed_talents={
                          project[:contributed_talents] || project["contributed_talents"] || []
                        }
                        class="h-full"
                      />
                    </div>
                  <% end %>
                </div>
              </section>
            <% end %>
            <!-- Game Stats Panel -->
            <div class="game-stats-container" role="region" aria-label="ゲーム状況">
              <!-- Gauges Row -->
              <div class="gauges-row" role="group" aria-label="パラメータゲージ">
                <div class="gauge-card gauge-card--forest" role="group" aria-label="Forest (F) ゲージ">
                  <span class="gauge-label text-matsu">
                    <span class="gauge-icon">🌲</span> Forest (F)
                  </span>
                  <div
                    class="gauge-track"
                    role="progressbar"
                    aria-valuenow={@game_state.forest}
                    aria-valuemin="0"
                    aria-valuemax="20"
                    aria-label={"Forest: #{@game_state.forest}"}
                  >
                    <div
                      id="forest-gauge-bar"
                      class="gauge-fill bg-matsu"
                      style={"width: #{gauge_width(@game_state.forest)}%"}
                      phx-update="ignore"
                    >
                    </div>
                    <span class="gauge-value">{@game_state.forest}</span>
                  </div>
                </div>

                <div class="gauge-card gauge-card--culture" role="group" aria-label="Culture (K) ゲージ">
                  <span class="gauge-label text-sakura">
                    <span class="gauge-icon">🎭</span> Culture (K)
                  </span>
                  <div
                    class="gauge-track"
                    role="progressbar"
                    aria-valuenow={@game_state[:culture] || @game_state.culture || 0}
                    aria-valuemin="0"
                    aria-valuemax="20"
                    aria-label={"Culture: #{@game_state[:culture] || @game_state.culture || 0}"}
                  >
                    <div
                      id="culture-gauge-bar"
                      class="gauge-fill bg-sakura"
                      style={"width: #{gauge_width(@game_state[:culture] || @game_state.culture || 0)}%"}
                      phx-update="ignore"
                    >
                    </div>
                    <span class="gauge-value">{@game_state[:culture] || @game_state.culture || 0}</span>
                  </div>
                </div>

                <div class="gauge-card gauge-card--social" role="group" aria-label="Social (S) ゲージ">
                  <span class="gauge-label text-kohaku">
                    <span class="gauge-icon">🤝</span> Social (S)
                  </span>
                  <div
                    class="gauge-track"
                    role="progressbar"
                    aria-valuenow={@game_state[:social] || @game_state.social || 0}
                    aria-valuemin="0"
                    aria-valuemax="20"
                    aria-label={"Social: #{@game_state[:social] || @game_state.social || 0}"}
                  >
                    <div
                      id="social-gauge-bar"
                      class="gauge-fill bg-kohaku"
                      style={"width: #{gauge_width(@game_state[:social] || @game_state.social || 0)}%"}
                      phx-update="ignore"
                    >
                    </div>
                    <span class="gauge-value">{@game_state[:social] || @game_state.social || 0}</span>
                  </div>
                </div>
              </div>

              <!-- Life Index Circle (Compact) -->
              <div class="life-index-compact" role="region" aria-label="Life Index表示">
                <div
                  class="life-index-circle"
                  aria-label={"Life Index: #{life_index(@game_state)}"}
                  role="meter"
                  aria-valuenow={life_index(@game_state)}
                  aria-valuemin="0"
                  aria-valuemax={@game_state[:life_index_target] || @game_state.life_index_target || 40}
                >
                  <svg class="life-index-svg" viewBox="0 0 120 120" aria-hidden="true">
                    <circle cx="60" cy="60" r="52" fill="none" stroke="rgba(255, 255, 255, 0.1)" stroke-width="6" />
                    <circle
                      cx="60"
                      cy="60"
                      r="52"
                      fill="none"
                      stroke="rgba(212, 175, 55, 0.6)"
                      stroke-width="6"
                      stroke-dasharray={2 * :math.pi() * 52}
                      stroke-dashoffset={
                        2 * :math.pi() * 52 * (1 - min(life_index(@game_state) / (@game_state[:life_index_target] || @game_state.life_index_target || 40), 1.0))
                      }
                      stroke-linecap="round"
                      class="life-index-progress"
                    />
                  </svg>
                  <div class="life-index-content">
                    <div class="life-index-label">L</div>
                    <div class="life-index-value">{life_index(@game_state)}</div>
                    <div class="life-index-target">/ {@game_state[:life_index_target] || @game_state.life_index_target || 40}</div>
                  </div>
                </div>
              </div>

              <!-- Actions Panel -->
              <% remaining_turns = max((@game_state.max_turns || 0) - (@game_state.turn || 0), 0) %>
              <div class="actions-panel" role="toolbar" aria-label="アクションボタン">
                <div class="actions-header">
                  <span class="actions-title">AKASHA ACTIONS</span>
                  <span class="actions-turns">残り {remaining_turns} ターン</span>
                </div>
                <div class="actions-buttons">
                  <.hanko_btn
                    :for={button <- @action_buttons}
                    label={button[:label] || button.label || button[:name] || button.name}
                    color={button[:color] || button.color || "sumi"}
                    class="action-hanko"
                    aria-label={(button[:label] || button.label || button[:name] || button.name) <> "を実行"}
                    phx-click="play_action_card"
                    phx-value-card_id={button[:id] || button.id}
                  />
                </div>
              </div>
            </div>
          <% end %>
          </div>
        </main>
      </div>

    <!-- Bottom Hand -->
      <div
        class="resonance-hand h-32 md:h-48 z-30 relative overflow-hidden"
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
          <%= for card <- @hand_cards do %>
            <% # Check if this card has talents stacked
            card_talents = get_card_talents(card.id, assigns) %>
            <div class="relative">
              <%= if length(card_talents) > 0 do %>
                <.action_card_with_talents
                  title={card.title}
                  cost={card.cost}
                  type={card.type}
                  talent_cards={card_talents}
                  tags={card[:tags] || card["tags"] || []}
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
                      if((@game_state[:currency] || @game_state.currency || 0) < card.cost_akasha,
                        do: "opacity-50 cursor-not-allowed",
                        else: "cursor-pointer"
                      )
                    ]
                    |> Enum.filter(&(&1 != ""))
                    |> Enum.join(" ")
                  }
                />
              <% else %>
                <.ofuda_card
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
                      if((@game_state[:currency] || @game_state.currency || 0) < card.cost_akasha,
                        do: "opacity-50 cursor-not-allowed",
                        else: "cursor-pointer"
                      )
                    ]
                    |> Enum.filter(&(&1 != ""))
                    |> Enum.join(" ")
                  }
                  aria-disabled={(@game_state[:currency] || @game_state.currency || 0) < card.cost_akasha}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

    <!-- Talent Cards Area (Action Phase) -->
      <%= if @current_phase == :action && length(@player_talents) > 0 do %>
        <div
          class="h-24 md:h-28 bg-kin/5 border-t-2 border-kin z-20 relative overflow-hidden"
          role="region"
          aria-label="才能カード"
        >
          <div class="absolute -top-3 md:-top-4 left-1/2 transform -translate-x-1/2 bg-kin text-washi px-3 md:px-4 py-0.5 rounded-t-lg font-bold shadow-md border-x-2 border-t-2 border-sumi text-[10px] md:text-xs z-10">
            才能カード
          </div>
          <div
            class="h-full w-full flex items-center justify-start md:justify-center gap-2 md:gap-3 px-4 md:px-6 overflow-x-auto scrollbar-thin scrollbar-thumb-kin scrollbar-track-transparent pb-2 pt-2"
            role="group"
            aria-label="利用可能な才能カード"
          >
            <.talent_card
              :for={talent <- @player_talents}
              title={talent[:name] || talent["name"] || "才能"}
              description={talent[:description] || talent["description"]}
              compatible_tags={talent[:compatible_tags] || talent["compatible_tags"] || []}
              is_used={talent[:is_used] || talent["is_used"] || false}
              is_selected={Enum.member?(@selected_talents_for_card, talent[:id] || talent["id"])}
              class="w-14 h-18 md:w-16 md:h-20"
            />
          </div>
        </div>
      <% end %>

    <!-- Talent Selector Modal -->
      <%= if @show_talent_selector && @talent_selector_card_id do %>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
          phx-click="close_talent_selector"
          role="dialog"
          aria-modal="true"
        >
          <div
            class="relative bg-washi border-4 border-double border-kin rounded-lg shadow-2xl max-w-lg w-full mx-4"
            phx-click-away="close_talent_selector"
          >
            <button
              class="absolute top-4 right-4 w-8 h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30 transition-colors"
              phx-click="close_talent_selector"
              aria-label="モーダルを閉じる"
            >
              <span class="text-lg font-bold">×</span>
            </button>
            <div class="p-6">
              <.talent_selector
                available_talents={@player_talents}
                selected_talent_ids={@selected_talents_for_card}
                action_card_tags={get_selected_card_tags(@talent_selector_card_id, assigns)}
                max_selection={2}
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>

    <!-- Action Confirm Modal -->
    <.action_confirm_modal
      show={@show_action_confirm}
      card={get_card_by_id(@confirm_card_id, assigns)}
      talent_cards={get_card_talents(@confirm_card_id, assigns)}
      current_currency={@game_state[:currency] || @game_state.currency || 0}
      current_params={
        %{
          forest: @game_state[:forest] || @game_state.forest || 0,
          culture: @game_state[:culture] || @game_state.culture || 0,
          social: @game_state[:social] || @game_state.social || 0,
          currency: @game_state.currency
        }
      }
      id="action-confirm-modal"
    />

    <!-- Project Contribute Modal -->
    <.project_contribute_modal
      show={@show_project_contribute}
      project={get_project_by_id(@project_contribute_id, assigns)}
      available_talents={@player_talents}
      id="project-contribute-modal"
    />

    <!-- Event Modal -->
    <.event_modal
      show={@show_event_modal}
      event={@current_event}
      id="event-modal"
    />

    <!-- Card Detail Modal -->
    <.card_detail_modal
      show={@show_card_detail}
      card={@detail_card}
      current_currency={@game_state[:currency] || @game_state.currency || 0}
      current_params={
        %{
          forest: @game_state[:forest] || @game_state.forest || 0,
          culture: @game_state[:culture] || @game_state.culture || 0,
          social: @game_state[:social] || @game_state.social || 0,
          currency: @game_state.currency
        }
      }
      id="card-detail-modal"
    />

    <!-- Demurrage Display Modal -->
    <.demurrage_modal
      show={@show_demurrage}
      previous_currency={@previous_currency}
      current_currency={@game_state.currency}
      demurrage_amount={@game_state[:demurrage] || @game_state.demurrage || 0}
      id="demurrage-modal"
    />

    <!-- Ending Screen -->
    <.ending_screen
      show={@show_ending}
      game_status={@game_status}
      life_index={life_index(@game_state)}
      final_stats={
        %{
          forest: @game_state.forest,
          culture: @game_state.culture,
          social: @game_state.social,
          currency: @game_state.currency
        }
      }
      turn={@game_state.turn}
      max_turns={@game_state.max_turns}
      id="ending-screen"
    />

    <!-- Role Selection Screen -->
    <.role_selection_screen
      show={@show_role_selection}
      selected_role={@selected_role}
      available_roles={[]}
      id="role-selection-screen"
    />

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
    # Show card detail modal
    card = Enum.find(socket.assigns.hand_cards, &(&1.id == card_id))

    if card do
      {:noreply,
       socket
       |> assign(:show_card_detail, true)
       |> assign(:detail_card, card)
       |> assign(:selected_card_id, card_id)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_card_detail", %{"card-id" => card_id}, socket) do
    card = Enum.find(socket.assigns.hand_cards, &(&1.id == card_id))

    if card do
      {:noreply,
       socket
       |> assign(:show_card_detail, true)
       |> assign(:detail_card, card)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_card_detail", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_card_detail, false)
     |> assign(:detail_card, nil)}
  end

  def handle_event("use_card", %{"card-id" => card_id}, socket) do
    # Show confirmation modal instead of using card directly
    card = Enum.find(socket.assigns.hand_cards, &(&1.id == card_id))

    if card do
      # If card has tags that can use talents, show talent selector first
      if card[:tags] && length(card[:tags]) > 0 do
        {:noreply,
         socket
         |> assign(:show_talent_selector, true)
         |> assign(:talent_selector_card_id, card_id)
         |> assign(:selected_talents_for_card, [])}
      else
        {:noreply,
         socket
         |> assign(:show_action_confirm, true)
         |> assign(:confirm_card_id, card_id)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("confirm_action", _params, socket) do
    card_id = socket.assigns.confirm_card_id
    game_session = socket.assigns.game_session
    user_id = socket.assigns.user_id
    selected_talents = socket.assigns[:selected_talents_for_card] || []

    if card_id do
      # プレイヤーを取得
      player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)

      if player do
        # アクションカードを取得
        action_card = Shinkanki.Repo.get!(Shinkanki.Games.ActionCard, card_id)

        # タレントが選択されていれば、タレント付きで実行
        result =
          if Enum.empty?(selected_talents) do
            Games.execute_action_card(player, action_card, game_session)
          else
            Games.execute_action_card_with_talents(player, action_card, game_session, selected_talents)
          end

        # アクションカードを実行
        case result do
          {:ok, updated_session} ->
            # ゲーム状態を更新
            Shinkanki.GamePubSub.broadcast_state_update(game_session.id, updated_session)

            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :success,
              message: "カード「#{action_card.name}」を使用しました。"
            }

            socket =
              socket
              |> assign(:selected_card_id, nil)
              |> assign(:show_action_confirm, false)
              |> assign(:confirm_card_id, nil)
              |> assign(:selected_talents_for_card, [])
              |> update(:toasts, fn toasts -> [new_toast | toasts] end)

            Process.send_after(self(), {:remove_toast, toast_id}, 3000)

            {:noreply, socket}

          {:error, :insufficient_resources} ->
            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :error,
              message: "リソースが不足しています。"
            }

            socket =
              socket
              |> assign(:show_action_confirm, false)
              |> assign(:confirm_card_id, nil)
              |> update(:toasts, fn toasts -> [new_toast | toasts] end)

            Process.send_after(self(), {:remove_toast, toast_id}, 3000)

            {:noreply, socket}

          error ->
            require Logger
            Logger.error("Failed to execute action card: #{inspect(error)}")

            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :error,
              message: "アクションの実行に失敗しました。"
            }

            socket =
              socket
              |> assign(:show_action_confirm, false)
              |> assign(:confirm_card_id, nil)
              |> update(:toasts, fn toasts -> [new_toast | toasts] end)

            Process.send_after(self(), {:remove_toast, toast_id}, 3000)

            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_action_confirm", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_action_confirm, false)
     |> assign(:confirm_card_id, nil)}
  end

  def handle_event("show_event_modal", _params, socket) do
    {:noreply, assign(socket, :show_event_modal, true)}
  end

  def handle_event("close_event_modal", _params, socket) do
    {:noreply, assign(socket, :show_event_modal, false)}
  end

  def handle_event(
        "add_talent_to_card",
        %{"talent-id" => _talent_id, "card-id" => card_id},
        socket
      ) do
    # Open talent selector for this card
    {:noreply,
     socket
     |> assign(:show_talent_selector, true)
     |> assign(:talent_selector_card_id, card_id)
     |> assign(:selected_talents_for_card, [])}
  end

  def handle_event("toggle_talent", %{"talent-id" => talent_id}, socket) do
    current_selected = socket.assigns.selected_talents_for_card

    new_selected =
      if Enum.member?(current_selected, talent_id) do
        List.delete(current_selected, talent_id)
      else
        if length(current_selected) < 2 do
          [talent_id | current_selected]
        else
          current_selected
        end
      end

    {:noreply, assign(socket, :selected_talents_for_card, new_selected)}
  end

  def handle_event("confirm_talent_selection", _params, socket) do
    # Close talent selector and show action confirmation
    card_id = socket.assigns.talent_selector_card_id

    {:noreply,
     socket
     |> assign(:show_talent_selector, false)
     |> assign(:show_action_confirm, true)
     |> assign(:confirm_card_id, card_id)
     |> assign(:talent_selector_card_id, nil)}
  end

  def handle_event("cancel_talent_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_talent_selector, false)
     |> assign(:talent_selector_card_id, nil)
     |> assign(:selected_talents_for_card, [])}
  end

  def handle_event("close_talent_selector", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_talent_selector, false)
     |> assign(:talent_selector_card_id, nil)
     |> assign(:selected_talents_for_card, [])}
  end

  def handle_event("open_project_contribute", %{"project-id" => project_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_project_contribute, true)
     |> assign(:project_contribute_id, project_id)
     |> assign(:selected_talent_for_contribution, nil)}
  end

  def handle_event(
        "contribute_talent",
        %{"talent-id" => talent_id, "project-id" => _project_id},
        socket
      ) do
    {:noreply, assign(socket, :selected_talent_for_contribution, talent_id)}
  end

  def handle_event("confirm_talent_contribution", _params, socket) do
    project_id = socket.assigns.project_contribute_id
    talent_id = socket.assigns.selected_talent_for_contribution
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    if project_id && talent_id do
      project_id_atom = convert_to_atom(project_id)
      talent_id_atom = convert_to_atom(talent_id)

      case Shinkanki.contribute_talent_to_project(
             room_id,
             user_id,
             project_id_atom,
             talent_id_atom
           ) do
        {:ok, _game} ->
          toast = %{
            id: Ecto.UUID.generate(),
            kind: :success,
            message: "才能カードをプロジェクトに捧げました"
          }

          {:noreply,
           socket
           |> assign(:show_project_contribute, false)
           |> assign(:project_contribute_id, nil)
           |> assign(:selected_talent_for_contribution, nil)
           |> update(:toasts, fn toasts -> [toast | toasts] end)}

        {:error, reason} ->
          toast = %{
            id: Ecto.UUID.generate(),
            kind: :error,
            message: "才能カードの貢献に失敗しました: #{inspect(reason)}"
          }

          {:noreply,
           socket
           |> assign(:show_project_contribute, false)
           |> assign(:project_contribute_id, nil)
           |> assign(:selected_talent_for_contribution, nil)
           |> update(:toasts, fn toasts -> [toast | toasts] end)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_project_contribute", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_project_contribute, false)
     |> assign(:project_contribute_id, nil)
     |> assign(:selected_talent_for_contribution, nil)}
  end

  def handle_event("restart_game", _params, socket) do
    # Reset game state (in real implementation, this would create a new game)
    {:noreply,
     socket
     |> assign(:game_state, mock_game_state())
     |> assign(:game_status, :playing)
     |> assign(:show_ending, false)
     |> assign(:hand_cards, mock_hand_cards())
     |> assign(:current_phase, :event)
     |> assign(:current_event, mock_current_event())
     |> assign(:selected_card_id, nil)}
  end

  def handle_event("close_ending", _params, socket) do
    {:noreply, assign(socket, :show_ending, false)}
  end

  def handle_event("select_role", %{"role-id" => role_id}, socket) do
    role_atom = String.to_existing_atom(role_id)
    {:noreply, assign(socket, :selected_role, role_atom)}
  end

  def handle_event("confirm_role_selection", _params, socket) do
    if socket.assigns.selected_role do
      toast = %{
        id: Ecto.UUID.generate(),
        kind: :success,
        message: "役割「#{get_role_name(socket.assigns.selected_role)}」を選択しました"
      }

      {:noreply,
       socket
       |> assign(:player_role, socket.assigns.selected_role)
       |> assign(:show_role_selection, false)
       |> assign(:selected_role, nil)
       |> update(:toasts, fn toasts -> [toast | toasts] end)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_role_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_role_selection, false)
     |> assign(:selected_role, nil)}
  end

  def handle_event("close_demurrage", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_demurrage, false)
     |> assign(:previous_currency, 0)}
  end

  def handle_event("show_demurrage", _params, socket) do
    # Show demurrage display (typically called when entering demurrage phase)
    previous = socket.assigns.game_state.currency

    {:noreply,
     socket
     |> assign(:show_demurrage, true)
     |> assign(:previous_currency, previous)}
  end

  # アクションカードを実行
  def handle_event("play_action_card", %{"card_id" => card_id}, socket) do
    game_session = socket.assigns.game_session
    user_id = socket.assigns.user_id

    # プレイヤーを取得
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)

    if player do
      # アクションカードを取得
      action_card = Shinkanki.Repo.get!(Shinkanki.Games.ActionCard, card_id)

      # アクションカードを実行
      case Games.execute_action_card(player, action_card, game_session) do
        {:ok, _updated_session} ->
          # ゲーム状態を更新（既にGamePubSubでブロードキャストされている）
          toast_id = "toast-#{System.unique_integer([:positive])}"
          new_toast = %{
            id: toast_id,
            kind: :success,
            message: "「#{action_card.name}」を実行しました。"
          }

          socket =
            socket
            |> update(:toasts, fn toasts -> [new_toast | toasts] end)

          Process.send_after(self(), {:remove_toast, toast_id}, 3000)

          {:noreply, socket}

        {:error, :insufficient_resources} ->
          toast_id = "toast-#{System.unique_integer([:positive])}"
          new_toast = %{
            id: toast_id,
            kind: :error,
            message: "リソースが不足しています。"
          }

          socket =
            socket
            |> update(:toasts, fn toasts -> [new_toast | toasts] end)

          Process.send_after(self(), {:remove_toast, toast_id}, 3000)

          {:noreply, socket}

        error ->
          require Logger
          Logger.error("Failed to execute action card: #{inspect(error)}")

          toast_id = "toast-#{System.unique_integer([:positive])}"
          new_toast = %{
            id: toast_id,
            kind: :error,
            message: "アクションの実行に失敗しました。"
          }

          socket =
            socket
            |> update(:toasts, fn toasts -> [new_toast | toasts] end)

          Process.send_after(self(), {:remove_toast, toast_id}, 3000)

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("execute_action", %{"action" => action}, socket) do
    case action do
      "play_card" ->
        # カードをプレイする処理（既存の実装を使用）
        {:noreply, socket}

      "mark_discussion_ready" ->
        # 討論フェーズで準備完了
        {:noreply, socket}

      "start_game" ->
        # ゲーム開始（待機ルームで処理済み）
        {:noreply, socket}

      _ ->
        # その他のアクション
        toast_id = "toast-#{System.unique_integer([:positive])}"

        new_toast = %{
          id: toast_id,
          kind: :info,
          message: "アクション「#{action}」を実行しました。"
        }

        socket =
          socket
          |> update(:toasts, fn toasts -> [new_toast | toasts] end)

        Process.send_after(self(), {:remove_toast, toast_id}, 3000)

        {:noreply, socket}
    end
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

  # GamePubSubからの更新を受け取る
  def handle_info({:game_state_updated, game_session}, socket) do
    # DBから最新のゲームセッションを取得
    updated_session = Games.get_game_session!(game_session.id)
    game_state = format_game_session(updated_session, socket.assigns.user_id)
    turn_state = get_current_turn_state(updated_session)
    current_phase = if turn_state, do: turn_state.phase, else: "event"

    # プレイヤーのAkashaを更新
    player = Enum.find(updated_session.players, fn p -> p.user_id == socket.assigns.user_id end)
    currency = if player, do: player.akasha, else: 0

    socket =
      socket
      |> assign(:game_session, updated_session)
      |> assign(:game_state, Map.put(game_state, :currency, currency))
      |> assign(:current_phase, current_phase)
      |> assign(:current_event, get_current_event(updated_session, turn_state))
      |> assign(:action_buttons, get_available_action_cards(updated_session, turn_state))
      |> assign(:hand_cards, get_hand_cards_from_session(updated_session, turn_state))
      |> assign(:player_talents, get_player_talents_from_session(updated_session, socket.assigns.user_id))
      |> assign(:active_projects, get_active_projects_from_session(updated_session))
      |> assign(:players, get_players_from_session(updated_session))
      |> assign(:player_role, get_player_role(updated_session, socket.assigns.user_id))
      |> assign(:show_ending, updated_session.status in ["completed", "failed"])
      |> assign(:game_status, updated_session.status)
      |> assign(:ending_type, get_ending_type(updated_session))

    {:noreply, socket}
  end

  def handle_info({:phase_changed, %{phase: new_phase}}, socket) do
    {:noreply, assign(socket, :current_phase, new_phase)}
  end

  def handle_info({:turn_started, %{turn: _turn_number, event_card: _event_card}}, socket) do
    # ターン開始時の処理
    {:noreply, socket}
  end

  def handle_info({:player_action, %{player_id: _player_id, action: _action}}, socket) do
    # プレイヤーアクションの処理
    {:noreply, socket}
  end

  def handle_info({:project_completed, _project}, socket) do
    # プロジェクト完成の処理
    {:noreply, socket}
  end

  def handle_info({:game_ended, result}, socket) do
    {:noreply,
     socket
     |> assign(:show_ending, true)
     |> assign(:game_status, "completed")
     |> assign(:ending_type, result)}
  end

  # 旧形式のメッセージ（後方互換性のため）
  def handle_info(%Phoenix.Socket.Broadcast{event: "game_state_updated", payload: game}, socket) do
    # Update game state when broadcast from GameServer
    new_status = game.status || :waiting
    new_phase = game.phase || :event
    previous_currency = socket.assigns.game_state[:currency] || 0

    # Show demurrage modal when entering demurrage phase
    entering_demurrage = new_phase == :demurrage && socket.assigns.current_phase != :demurrage

    socket =
      socket
      |> assign(:game_state, format_game_state(game))
      |> assign(:current_phase, new_phase)
      |> assign(:current_event, format_current_event(game))
      |> assign(:game_status, new_status)
      |> assign(:hand_cards, get_hand_cards(game, socket.assigns.user_id))
      |> assign(:player_talents, get_player_talents(game, socket.assigns.user_id))
      |> assign(:active_projects, get_active_projects(game))
      |> assign(:can_start, Shinkanki.can_start?(socket.assigns.room_id))
      # Show ending screen if game ended
      |> assign(:show_ending, new_status in [:won, :lost])
      |> assign(:ending_type, game.ending_type)
      # Show demurrage modal when entering demurrage phase
      |> assign(
        :show_demurrage,
        if(entering_demurrage, do: true, else: socket.assigns.show_demurrage)
      )
      |> assign(
        :previous_currency,
        if(entering_demurrage, do: previous_currency, else: socket.assigns.previous_currency)
      )

    {:noreply, socket}
  end

  def handle_info({:remove_toast, toast_id}, socket) do
    {:noreply,
     update(socket, :toasts, fn toasts -> Enum.reject(toasts, &(&1.id == toast_id)) end)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp life_index(state) do
    forest = state[:forest] || state.forest || 0
    culture = state[:culture] || state.culture || 0
    social = state[:social] || state.social || 0
    forest + culture + social
  end

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
      life_index_target: 40,
      phase: :action
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

  defp mock_current_event do
    %{
      title: "神々の加護",
      description: "古来より伝わる神々の加護が降り注ぎ、森と文化が共に栄える。",
      effect: %{forest: 2, culture: 2, social: 1},
      category: :blessing
    }
  end

  defp mock_player_talents do
    [
      %{
        id: :t_craft,
        name: "手しごとの才能",
        description: "Good at making things.",
        compatible_tags: [:craft, :make, :fix],
        is_used: false
      },
      %{
        id: :t_grow,
        name: "育てる才能",
        description: "Good at growing plants and people.",
        compatible_tags: [:nature, :grow, :edu],
        is_used: false
      },
      %{
        id: :t_listen,
        name: "聴く才能",
        description: "Good at listening and care.",
        compatible_tags: [:community, :care, :dialogue],
        is_used: false
      }
    ]
  end

  # Helper function to get talents for a specific card
  defp get_card_talents(_card_id, _assigns) do
    # In real implementation, this would check the game state
    # For now, return empty list
    []
  end

  # Helper function to get tags for a selected card
  defp get_selected_card_tags(card_id, assigns) when is_binary(card_id) do
    card = Enum.find(assigns.hand_cards, &(&1.id == card_id))
    if card, do: card[:tags] || card["tags"] || [], else: []
  end

  defp get_selected_card_tags(_card_id, _assigns), do: []

  defp mock_active_projects do
    [
      %{
        id: :p_forest_fest,
        name: "森の祝祭",
        description: "森と文化が共に栄える大規模な祝祭を開催する。",
        cost: 50,
        progress: 25,
        effect: %{forest: 10, culture: 10, social: 10},
        unlock_condition: %{forest: 80, culture: 60},
        is_unlocked: true,
        is_completed: false,
        contributed_talents: [
          %{name: "育てる才能"},
          %{name: "企画の才能"}
        ]
      },
      %{
        id: :p_market,
        name: "定期市",
        description: "定期的な市場システムを確立する。",
        cost: 30,
        progress: 0,
        effect: %{currency: 30, social: 5},
        unlock_condition: %{social: 70},
        is_unlocked: false,
        is_completed: false,
        contributed_talents: []
      }
    ]
  end

  defp get_project_by_id(project_id, assigns) when is_binary(project_id) or is_atom(project_id) do
    Enum.find(assigns.active_projects, fn p ->
      (p[:id] || p["id"]) == project_id
    end)
  end

  defp get_project_by_id(_project_id, _assigns), do: nil

  defp get_card_by_id(card_id, assigns) when is_binary(card_id) do
    Enum.find(assigns.hand_cards, &(&1.id == card_id))
  end

  defp get_card_by_id(_card_id, _assigns), do: nil

  defp get_role_name(:forest_guardian), do: "森の守り手"
  defp get_role_name(:culture_keeper), do: "文化の継承者"
  defp get_role_name(:community_light), do: "コミュニティの灯火"
  defp get_role_name(:akasha_engineer), do: "空環エンジニア"
  defp get_role_name(_), do: "不明"


  defp format_game_state(nil), do: mock_game_state()

  defp format_game_state(%{} = game) do
    %{
      room: game.room_id || "UNKNOWN",
      turn: game.turn || 1,
      max_turns: 20,
      forest: game.forest || 50,
      culture: game.culture || 50,
      social: game.social || 50,
      currency: game.currency || 100,
      demurrage: calculate_demurrage(game.currency || 100),
      life_index_target: 40,
      phase: game.phase || :event
    }
  end

  defp calculate_demurrage(currency) do
    new_currency = floor(currency * 0.9)
    new_currency - currency
  end

  defp format_current_event(nil), do: nil
  defp format_current_event(%{current_event: nil}), do: nil

  defp format_current_event(%{current_event: event_id}) when is_atom(event_id) do
    case Shinkanki.Card.get_event(event_id) do
      nil ->
        nil

      event ->
        %{
          title: event.name,
          description: event.description,
          effect: event.effect,
          category: get_event_category(event.tags)
        }
    end
  end

  defp format_current_event(%{current_event: event_id}) when is_binary(event_id) do
    event_id_atom = convert_to_atom(event_id)
    format_current_event(%{current_event: event_id_atom})
  end

  defp format_current_event(_), do: nil

  defp get_event_category(tags) when is_list(tags) do
    cond do
      Enum.member?(tags, :disaster) -> :disaster
      Enum.member?(tags, :festival) -> :festival
      Enum.member?(tags, :blessing) -> :blessing
      Enum.member?(tags, :economy) -> :economy
      true -> :neutral
    end
  end

  defp get_event_category(_), do: :neutral

  defp get_hand_cards(nil, _user_id), do: mock_hand_cards()

  defp get_hand_cards(%{hands: hands} = _game, user_id) when is_map(hands) do
    case Map.get(hands, user_id) do
      nil ->
        []

      card_ids when is_list(card_ids) ->
        Enum.map(card_ids, fn card_id ->
          case Shinkanki.Card.get_action(card_id) do
            nil ->
              nil

            card ->
              %{
                id: card.id,
                title: card.name,
                cost: card.cost || 0,
                type: card.type || :action,
                tags: card.tags || []
              }
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp get_hand_cards(_game, _user_id), do: mock_hand_cards()

  defp get_player_talents(nil, _user_id), do: mock_player_talents()

  defp get_player_talents(%{players: players} = _game, user_id) when is_map(players) do
    case Map.get(players, user_id) do
      nil ->
        []

      player ->
        Enum.map(player.talents || [], fn talent_id ->
          talent_id_atom = convert_to_atom(talent_id)

          case Shinkanki.Card.get_talent(talent_id_atom) do
            nil ->
              nil

            talent ->
              %{
                id: talent.id,
                name: talent.name,
                description: talent.description,
                compatible_tags: talent.compatible_tags || [],
                is_used: Enum.member?(player.used_talents || [], talent_id)
              }
          end
        end)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp get_player_talents(_game, _user_id), do: mock_player_talents()

  defp get_active_projects(nil), do: mock_active_projects()

  defp get_active_projects(%{available_projects: projects} = game) when is_list(projects) do
    Enum.map(projects, fn project_id ->
      project_id_atom = convert_to_atom(project_id)

      case Shinkanki.Card.get_project(project_id_atom) do
        nil ->
          nil

        project ->
          progress_data = Map.get(game.project_progress || %{}, project_id, %{})
          progress = Map.get(progress_data, :progress, 0)
          is_completed = Enum.member?(game.completed_projects || [], project_id)

          %{
            id: project.id,
            name: project.name,
            description: project.description,
            cost: project.cost || 0,
            progress: progress,
            required_progress: project.required_progress || 0,
            effect: project.effect || %{},
            unlock_condition: project.unlock_condition || %{},
            is_unlocked: true,
            is_completed: is_completed,
            contributed_talents: []
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_active_projects(_game), do: mock_active_projects()

  defp convert_to_atom(id) when is_atom(id), do: id

  defp convert_to_atom(id) when is_binary(id) do
    try do
      String.to_existing_atom(id)
    rescue
      ArgumentError ->
        # If atom doesn't exist, try to create it (for development)
        String.to_atom(id)
    end
  end

  defp convert_to_atom(id), do: id

  defp get_player_ready_status(players, user_id) when is_list(players) do
    case Enum.find(players, fn p -> (p[:id] || p["id"]) == user_id end) do
      nil -> false
      player -> player[:is_ready] || player["is_ready"] || false
    end
  end

  defp get_player_ready_status(_players, _user_id), do: false

  defp get_current_player_name(game_state, players) when is_list(players) do
    # Get current player from game state
    current_player_id =
      case game_state do
        %{player_order: order, current_player_index: index} when is_list(order) and index >= 0 ->
          Enum.at(order, index)

        _ ->
          nil
      end

    case current_player_id do
      nil ->
        nil

      id ->
        case Enum.find(players, fn p -> (p[:id] || p["id"]) == id end) do
          nil -> "Player #{String.slice(id, 0, 8)}"
          player -> player[:name] || player["name"] || "Player"
        end
    end
  end

  defp get_current_player_name(_game_state, _players), do: nil

  defp is_current_player_turn(game_state, user_id) do
    case game_state do
      %{player_order: order, current_player_index: index} when is_list(order) and index >= 0 ->
        current_player_id = Enum.at(order, index)
        current_player_id == user_id

      _ ->
        false
    end
  end

  # ===================
  # DB連携ヘルパー関数
  # ===================

  # 場に出ているアクションカードを手札として取得（DBベース）
  defp get_hand_cards_from_session(_game_session, turn_state) do
    if turn_state && turn_state.available_cards do
      Shinkanki.Games.ActionCard
      |> Shinkanki.Repo.all()
      |> Enum.filter(fn card -> card.id in turn_state.available_cards end)
      |> Enum.map(fn card ->
        %{
          id: card.id,
          title: card.name,
          cost: card.cost_akasha,
          cost_akasha: card.cost_akasha,
          cost_forest: card.cost_forest,
          cost_culture: card.cost_culture,
          cost_social: card.cost_social,
          type: card_type_from_category(card.category),
          category: card.category,
          description: card.description,
          effect_forest: card.effect_forest,
          effect_culture: card.effect_culture,
          effect_social: card.effect_social,
          effect_akasha: card.effect_akasha,
          tags: [String.to_atom(card.category)]
        }
      end)
    else
      []
    end
  end

  # カテゴリからカードタイプを決定
  defp card_type_from_category("forest"), do: :action
  defp card_type_from_category("culture"), do: :event
  defp card_type_from_category("social"), do: :reaction
  defp card_type_from_category("akasha"), do: :action
  defp card_type_from_category(_), do: :action

  # プレイヤーのタレント（才能）を取得（DBベース）
  defp get_player_talents_from_session(game_session, user_id) do
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)

    if player do
      # プレイヤーにタレントが割り当てられているか確認
      player_with_talents = Shinkanki.Repo.preload(player, player_talents: :talent_card)

      if Enum.empty?(player_with_talents.player_talents) do
        # タレントがまだ割り当てられていない場合は、ダミーデータを返す（フォールバック）
        role_talents_fallback(player.role)
      else
        # DBからタレントを取得
        Enum.map(player_with_talents.player_talents, fn pt ->
          %{
            id: pt.talent_card.id,
            name: pt.talent_card.name,
            description: pt.talent_card.description,
            compatible_tags: Enum.map(pt.talent_card.compatible_tags, &String.to_atom/1),
            effect_type: pt.talent_card.effect_type,
            effect_value: pt.talent_card.effect_value,
            is_used: pt.is_used,
            player_talent_id: pt.id
          }
        end)
      end
    else
      []
    end
  end

  # フォールバック用のダミータレントデータ（DBにタレントがない場合用）
  defp role_talents_fallback("forest_guardian") do
    [
      %{
        id: "talent_forest_1",
        name: "森の知恵",
        description: "森への理解を深め、Forest系カードの効果+1",
        compatible_tags: [:forest],
        is_used: false
      },
      %{
        id: "talent_forest_2",
        name: "自然との対話",
        description: "自然の声を聞き、調和をもたらす",
        compatible_tags: [:forest, :social],
        is_used: false
      }
    ]
  end

  defp role_talents_fallback("heritage_weaver") do
    [
      %{
        id: "talent_culture_1",
        name: "伝承の継承",
        description: "文化への理解を深め、Culture系カードの効果+1",
        compatible_tags: [:culture],
        is_used: false
      },
      %{
        id: "talent_culture_2",
        name: "物語の紡ぎ手",
        description: "物語を通じて人々の心をつなぐ",
        compatible_tags: [:culture, :social],
        is_used: false
      }
    ]
  end

  defp role_talents_fallback("community_keeper") do
    [
      %{
        id: "talent_social_1",
        name: "絆の守り手",
        description: "社会への理解を深め、Social系カードの効果+1",
        compatible_tags: [:social],
        is_used: false
      },
      %{
        id: "talent_social_2",
        name: "調停者",
        description: "対立を解消し、協力を促進する",
        compatible_tags: [:social, :culture],
        is_used: false
      }
    ]
  end

  defp role_talents_fallback("akasha_architect") do
    [
      %{
        id: "talent_akasha_1",
        name: "空環の設計者",
        description: "Akashaの流れを読み、効率的に運用する",
        compatible_tags: [:akasha],
        is_used: false
      },
      %{
        id: "talent_akasha_2",
        name: "循環の知恵",
        description: "リソースの循環を最適化する",
        compatible_tags: [:akasha, :forest],
        is_used: false
      }
    ]
  end

  defp role_talents_fallback(_), do: []

  # 減衰量を計算（10%）
  defp calculate_demurrage_amount(currency) when is_integer(currency) and currency > 0 do
    -div(currency, 10)
  end

  defp calculate_demurrage_amount(_), do: 0
end
