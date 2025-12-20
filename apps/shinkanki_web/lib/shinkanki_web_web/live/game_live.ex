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

              mount_with_game_session(
                socket,
                room_id,
                user_id,
                user_email,
                current_user,
                game_session,
                game_state
              )
            end
        end
      end
    end
  end

  defp mount_with_game_session(
         socket,
         room_id,
         user_id,
         user_email,
         current_user,
         game_session,
         game_state
       ) do
    # 現在のターン状態を取得
    turn_state = get_current_turn_state(game_session)
    current_phase = if turn_state, do: turn_state.phase, else: "event"
    hand_cards = get_hand_cards_from_session(game_session, turn_state)

    # Debug logging
    require Logger
    Logger.info("[DEBUG] GameLive mount: turn_state=#{inspect(turn_state != nil)}, phase=#{current_phase}, hand_cards_count=#{length(hand_cards)}")
    if turn_state do
      Logger.info("[DEBUG] turn_state.available_cards=#{inspect(turn_state.available_cards)}")
    end

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
      |> assign(:hand_cards, hand_cards)
      |> assign(:action_buttons, get_available_action_cards(game_session, turn_state))
      |> assign(:chat_form, chat_form())
      |> assign(:toasts, [])
      |> assign(:selected_card_id, nil)
      |> assign(:current_phase, current_phase)
      |> assign(:current_event, get_current_event(game_session, turn_state))
      |> assign(:show_event_modal, false)
      |> assign(:player_talents, [])
      |> assign(:selected_talents_for_card, [])
      |> assign(:show_talent_selector, false)
      |> assign(:talent_selector_card_id, nil)
      |> assign(:active_projects, [])
      |> assign(:show_project_contribute, false)
      |> assign(:project_contribute_id, nil)
      |> assign(:selected_talent_for_contribution, nil)
      |> assign(:show_action_confirm, false)
      |> assign(:confirm_card_id, nil)
      |> assign(:show_ending, game_session.status in ["completed", "failed"])
      |> assign(:game_status, game_session.status)
      |> assign(:ending_type, nil)
      |> assign(:show_role_selection, false)
      |> assign(:selected_role, nil)
      |> assign(:player_role, nil)
      |> assign(:players, get_players_from_session(game_session))
      |> assign(:show_demurrage, false)
      |> assign(:previous_currency, 0)
      |> assign(:show_card_detail, false)
      |> assign(:detail_card, nil)
      # ゲームは既に開始されている
      |> assign(:can_start, false)
      |> assign(:action_logs, [])
      |> assign(:migaki_cards, [])
      |> assign(:selected_migaki_id, nil)
      |> assign(:show_migaki_panel, false)
      # フェーズ確認用タイマー（30秒で自動進行）
      |> assign(:phase_auto_advance_timer, nil)
      |> assign(:phase_countdown, 30)
      # 人代フェーズで引いたカード
      |> assign(:drawn_hitoyo_cards, [])
      # Mobile UI用
      |> assign(:active_tab, :game)
      |> assign(:show_card_fullscreen, false)
      |> assign(:fullscreen_card, nil)
      # 連携カードシステム
      |> assign(:available_renkei_cards, [])
      |> assign(:pending_renkei, %{})
      |> assign(:show_renkei_detail, false)
      |> assign(:selected_renkei_id, nil)

    socket =
      if connected?(socket) do
        # Subscribe to rogs_comm PubSub for real-time chat updates
        chat_topic = "room:#{room_id}"
        Phoenix.PubSub.subscribe(CommPubSub, chat_topic)

        # Subscribe to GamePubSub for game state updates (DB-based)
        Shinkanki.GamePubSub.subscribe(game_session.id)

        # Subscribe to Shinkanki PubSub for AI chat messages (memory-based game)
        shinkanki_topic = "shinkanki:game:#{room_id}"
        Phoenix.PubSub.subscribe(Shinkanki.PubSub, shinkanki_topic)

        # Load initial messages - start empty, will load via PubSub
        # AI自動行動をトリガー（ゲームにAIプレイヤーがいる場合）
        if Enum.any?(game_session.players, fn p -> p.is_ai end) do
          Process.send_after(self(), {:ai_auto_action, game_session.id}, 500)
        end

        stream(socket, :chat_messages, [], reset: true)
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
    player_evil = if player, do: player.evil_tokens || 0, else: 0

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
      current_user_id: user_id,
      # 邪気・オロチシステム
      evil_pool: game_session.evil_pool || 0,
      evil_threshold: game_session.evil_threshold || 3,
      orochi_level: game_session.orochi_level || 0,
      current_policy: game_session.current_policy,
      player_evil: player_evil
    }
  end

  # 現在のターン状態を取得
  defp get_current_turn_state(game_session) do
    game_session.turn_states
    |> Enum.find(fn ts -> ts.turn_number == game_session.turn end)
  end

  # 利用可能なアクションカードを取得（キャッシュから）
  defp get_available_action_cards(_game_session, turn_state) do
    if turn_state && turn_state.available_cards do
      turn_state.available_cards
      |> Shinkanki.CardCache.action_cards_by_ids()
      |> Enum.map(fn card ->
        # カテゴリに応じた色を設定
        color =
          case card.category do
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

  # 現在のイベントカードを取得（キャッシュから）
  defp get_current_event(_game_session, turn_state) do
    if turn_state && turn_state.current_event_id do
      event = Shinkanki.CardCache.get_event_card(turn_state.current_event_id)

      if event do
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
    else
      nil
    end
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
    <div class="min-h-screen flex flex-col bg-[var(--color-midnight)] text-[var(--color-landing-text-primary)]">
      <!-- =========================================== -->
      <!-- MOBILE UI (sm:hidden) -->
      <!-- =========================================== -->
      <.mobile_compact_header game_state={@game_state} current_phase={@current_phase} />

      <!-- Mobile Tab Content -->
      <main class="sm:hidden flex-1 pt-12 pb-20 overflow-auto">
        <!-- Game Tab -->
        <div :if={@active_tab == :game} class="p-4 space-y-4">
          {render_mobile_game_tab(assigns)}
        </div>

        <!-- Hand Tab -->
        <div :if={@active_tab == :hand} class="p-4 space-y-3">
          <%= if Enum.empty?(@hand_cards) do %>
            <div class="text-center py-8">
              <span class="text-4xl mb-4 block">🃏</span>
              <p class="text-[var(--color-landing-text-secondary)]">手札がありません</p>
            </div>
          <% else %>
            <%= for card <- @hand_cards do %>
              <.mobile_hand_card card={card} selected={@selected_card_id == card.id} />
            <% end %>
          <% end %>
        </div>

        <!-- Renkei Tab -->
        <div :if={@active_tab == :renkei} class="p-4 space-y-4 pb-20">
          <!-- 八岐大蛇ステータス -->
          <div class="bg-gradient-to-r from-red-900/30 to-purple-900/30 rounded-xl p-4 border border-red-500/30">
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-lg font-bold text-red-400">🐉 八岐大蛇</h3>
              <span class="text-2xl font-bold text-red-300">Lv.{@game_state[:orochi_level] || 1}</span>
            </div>
            <div class="flex gap-1 mb-2">
              <%= for i <- 1..3 do %>
                <div class={"flex-1 h-2 rounded-full #{if i <= (@game_state[:orochi_level] || 1), do: "bg-red-500", else: "bg-red-900/50"}"}></div>
              <% end %>
            </div>
            <p class="text-xs text-red-200/70">
              <%= case @game_state[:orochi_level] || 1 do %>
                <% 1 -> %>眠りについている...
                <% 2 -> %>⚠️ 覚醒の兆し！人代カード効果1.5倍
                <% 3 -> %>🔥 完全覚醒！人代カード効果2倍
              <% end %>
            </p>
          </div>

          <!-- 進行中の連携 -->
          <%= if map_size(@pending_renkei) > 0 do %>
            <div class="bg-purple-900/20 rounded-xl p-4 border border-purple-500/30">
              <h3 class="text-lg font-bold text-purple-400 mb-3">🔮 進行中の連携</h3>
              <div class="space-y-2">
                <%= for {renkei_id, pending} <- @pending_renkei do %>
                  <% card = Enum.find(@available_renkei_cards, &(&1.id == renkei_id)) %>
                  <%= if card do %>
                    <div class="bg-white/5 rounded-lg p-3 border border-purple-400/30">
                      <div class="flex items-center justify-between">
                        <div class="font-bold text-[var(--color-landing-pale)]">{card.name}</div>
                        <span class="text-xs text-purple-300">
                          {length(pending.participants)}/{card.required_players}人
                        </span>
                      </div>
                      <div class="mt-2 flex gap-2">
                        <%= if @user_id in pending.participants do %>
                          <span class="text-xs text-green-400">✓ 参加中</span>
                        <% else %>
                          <button
                            phx-click="join_renkei"
                            phx-value-renkei-id={renkei_id}
                            class="px-3 py-1 text-xs bg-purple-500 text-white rounded-lg hover:bg-purple-400"
                          >
                            参加する
                          </button>
                        <% end %>
                        <%= if pending.initiator == @user_id do %>
                          <button
                            phx-click="cancel_renkei"
                            phx-value-renkei-id={renkei_id}
                            class="px-3 py-1 text-xs bg-red-500/50 text-white rounded-lg hover:bg-red-500"
                          >
                            キャンセル
                          </button>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- 利用可能な連携カード -->
          <div class="bg-white/5 rounded-xl p-4">
            <h3 class="text-lg font-bold text-[var(--color-landing-gold)] mb-3">✨ 利用可能な連携カード</h3>
            <div class="space-y-3">
              <%= for card <- @available_renkei_cards do %>
                <% is_pending = Map.has_key?(@pending_renkei, card.id) %>
                <div class={"bg-white/5 rounded-lg p-3 border transition-all #{if is_pending, do: "border-purple-400/50 opacity-50", else: "border-[var(--color-landing-gold)]/20 hover:border-[var(--color-landing-gold)]/50"}"}>
                  <div class="flex items-start justify-between gap-2">
                    <div class="flex-1">
                      <div class="font-bold text-[var(--color-landing-pale)] text-sm">{card.name}</div>
                      <p class="text-xs text-[var(--color-landing-text-secondary)] mt-1">{card.description}</p>
                      <div class="flex flex-wrap gap-1 mt-2">
                        <%= for tag <- card.tags || [] do %>
                          <span class="text-xs px-1.5 py-0.5 bg-white/10 rounded">{renkei_tag_emoji(tag)}</span>
                        <% end %>
                      </div>
                    </div>
                    <div class="text-right shrink-0">
                      <div class="text-xs text-purple-300">{card.required_players}人必要</div>
                      <div class="text-xs text-yellow-300">各{card.cost_per_player}P</div>
                    </div>
                  </div>
                  <div class="mt-2 flex items-center justify-between">
                    <div class="text-xs text-green-300">
                      効果: <%= render_effect_summary(card.effect) %>
                    </div>
                    <%= unless is_pending do %>
                      <button
                        phx-click="initiate_renkei"
                        phx-value-renkei-id={card.id}
                        class="px-3 py-1 text-xs bg-[var(--color-landing-gold)] text-black font-bold rounded-lg hover:opacity-80"
                      >
                        提案する
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Chat Tab -->
        <div :if={@active_tab == :chat} class="flex flex-col h-full">
          <div class="flex-1 p-4 overflow-y-auto space-y-2">
            <div id="mobile-chat-messages" phx-update="stream" class="space-y-2">
              <div :for={{id, msg} <- @streams.chat_messages} id={id} class="bg-white/5 rounded-lg p-3">
                <div class="text-xs text-[var(--color-landing-gold)] mb-1">{msg.user_email}</div>
                <div class="text-sm text-[var(--color-landing-pale)]">{msg.content}</div>
              </div>
            </div>
          </div>
          <div class="p-4 border-t border-[var(--color-landing-gold)]/20">
            <.form for={@chat_form} phx-submit="send_chat" phx-change="validate_chat" class="flex gap-2">
              <input
                type="text"
                name="chat[content]"
                placeholder="メッセージを入力..."
                class="flex-1 bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-sm text-white placeholder-white/50 focus:outline-none focus:border-[var(--color-landing-gold)]"
                autocomplete="off"
              />
              <button type="submit" class="px-4 py-2 bg-[var(--color-landing-gold)] text-black font-bold rounded-lg">
                送信
              </button>
            </.form>
          </div>
        </div>
      </main>

      <.mobile_tab_bar active_tab={@active_tab} hand_count={length(@hand_cards)} />

      <.fullscreen_card_modal card={@fullscreen_card} show={@show_card_fullscreen} />

      <!-- =========================================== -->
      <!-- DESKTOP UI (hidden sm:flex) -->
      <!-- =========================================== -->

      <!-- Ultra Compact Top Bar for Desktop -->
      <header class="hidden sm:flex sticky top-0 z-40 items-center justify-between px-2 sm:px-4 py-1 sm:py-2 bg-[rgba(15,20,25,0.92)] backdrop-blur-md border-b border-[var(--color-landing-gold)]/20 safe-top">
        <!-- Left: Turn & Phase (super compact on mobile) -->
        <div class="flex items-center gap-1 sm:gap-3">
          <span class="text-[10px] sm:text-sm font-bold text-[var(--color-landing-gold)]">
            T{@game_state.turn}
          </span>
          <span class="text-[9px] sm:text-xs px-1 sm:px-2 py-0.5 rounded bg-white/10 text-[var(--color-landing-pale)] truncate max-w-[60px] sm:max-w-none">
            {phase_name_short(@current_phase)}
          </span>
        </div>
        
    <!-- Center: World Stats - Always visible -->
        <div class="flex items-center gap-2 sm:gap-4">
          <!-- 森・文化・絆 -->
          <div class="flex items-center gap-1.5 sm:gap-3 text-[10px] sm:text-sm">
            <div class="flex items-center gap-0.5" title="森">
              <span>🌲</span>
              <span class="font-bold text-matsu">{@game_state.forest}</span>
            </div>
            <div class="flex items-center gap-0.5" title="文化">
              <span>🎭</span>
              <span class="font-bold text-sakura">
                {@game_state[:culture] || @game_state.culture || 0}
              </span>
            </div>
            <div class="flex items-center gap-0.5" title="絆">
              <span>🤝</span>
              <span class="font-bold text-kohaku">
                {@game_state[:social] || @game_state.social || 0}
              </span>
            </div>
          </div>
          <!-- Life Index -->
          <div
            class="flex items-center gap-0.5 bg-white/5 px-1.5 sm:px-2 py-0.5 rounded"
            title="生命指数"
          >
            <span class="text-[9px] sm:text-xs text-[var(--color-landing-gold)]">L</span>
            <span class="text-xs sm:text-base font-bold text-[var(--color-landing-gold)]">
              {life_index(@game_state)}
            </span>
            <span class="text-[8px] sm:text-xs text-[var(--color-landing-text-secondary)]">/40</span>
          </div>
        </div>
        
    <!-- Right: Akasha, Toggle buttons & Avatar -->
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="flex items-center gap-0.5 text-[10px] sm:text-sm">
            <span class="text-[var(--color-landing-gold)]">φ</span>
            <span class="font-bold text-[var(--color-landing-gold)]">
              {@game_state[:currency] || @game_state.currency || 0}
            </span>
          </div>
          <!-- Stats button with label -->
          <button
            phx-click={JS.toggle(to: "#stats-panel")}
            class="flex items-center gap-1 px-2 py-1 rounded bg-[var(--color-landing-gold)]/20 hover:bg-[var(--color-landing-gold)]/30 text-[var(--color-landing-gold)] transition-colors active:scale-95 border border-[var(--color-landing-gold)]/30"
            aria-label="詳細を表示"
            title="ゲーム状態の詳細を表示"
          >
            <.icon name="hero-chart-bar" class="w-3 h-3 sm:w-4 sm:h-4" />
            <span class="hidden sm:inline text-xs">詳細</span>
          </button>
          <!-- Chat button with label -->
          <button
            phx-click={JS.toggle(to: "#chat-panel")}
            class="flex items-center gap-1 px-2 py-1 rounded bg-blue-500/20 hover:bg-blue-500/30 text-blue-300 transition-colors active:scale-95 border border-blue-500/30"
            aria-label="チャットを表示"
            title="チャットを開く"
          >
            <.icon name="hero-chat-bubble-left-right" class="w-3 h-3 sm:w-4 sm:h-4" />
            <span class="hidden sm:inline text-xs">チャット</span>
          </button>
          <!-- Profile Avatar -->
          <%= if @current_user do %>
            <.link navigate={~p"/profile"} class="flex-shrink-0" title="プロフィール">
              <div class="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-white/10 border-2 border-white/20 flex items-center justify-center text-base sm:text-lg hover:border-[var(--color-landing-gold)] hover:bg-white/15 transition-all cursor-pointer">
                {RogsIdentity.Accounts.User.avatar(@current_user)}
              </div>
            </.link>
          <% end %>
        </div>
      </header>
      
    <!-- Stats Panel (hidden by default) - Ultra compact on mobile -->
      <div
        id="stats-panel"
        class="hidden bg-[rgba(15,20,25,0.95)] border-b border-[var(--color-landing-gold)]/20 px-2 sm:px-4 py-1.5 sm:py-3"
      >
        <!-- パラメータ表示 -->
        <div class="flex items-center justify-center gap-2 sm:gap-6 text-[10px] sm:text-sm mb-2">
          <div class="flex items-center gap-0.5">
            <span>🌲</span>
            <span class="font-bold text-matsu">{@game_state.forest}</span>
          </div>
          <div class="flex items-center gap-0.5">
            <span>🎭</span>
            <span class="font-bold text-sakura">
              {@game_state[:culture] || @game_state.culture || 0}
            </span>
          </div>
          <div class="flex items-center gap-0.5">
            <span>🤝</span>
            <span class="font-bold text-kohaku">
              {@game_state[:social] || @game_state.social || 0}
            </span>
          </div>
        </div>
        
    <!-- 邪気・オロチ表示 -->
        <div class="flex items-center justify-center gap-3 sm:gap-6 text-[10px] sm:text-sm pt-2 border-t border-white/10">
          <!-- 邪気プール -->
          <div class="flex items-center gap-1">
            <span class="text-purple-400">👻</span>
            <span class="text-[8px] sm:text-xs text-[var(--color-landing-text-secondary)]">邪気</span>
            <div class="flex gap-0.5">
              <%= for i <- 1..(@game_state[:evil_threshold] || 3) do %>
                <div class={"w-2 h-2 sm:w-3 sm:h-3 rounded-full border #{if i <= (@game_state[:evil_pool] || 0), do: "bg-purple-500 border-purple-400", else: "border-purple-400/30"}"} />
              <% end %>
            </div>
          </div>
          
    <!-- オロチレベル -->
          <div class="flex items-center gap-1">
            <span class="text-shu">🐍</span>
            <span class="text-[8px] sm:text-xs text-[var(--color-landing-text-secondary)]">オロチ</span>
            <div class="flex gap-0.5">
              <%= for i <- 1..3 do %>
                <div class={"w-2 h-2 sm:w-3 sm:h-3 rounded-full border #{if i <= (@game_state[:orochi_level] || 0), do: "bg-shu border-shu", else: "border-shu/30"}"} />
              <% end %>
            </div>
            <%= if (@game_state[:orochi_level] || 0) > 0 do %>
              <span class="text-[8px] text-shu font-bold">
                Lv.{@game_state[:orochi_level]}
              </span>
            <% end %>
          </div>
          
    <!-- 個人邪気 -->
          <div class="flex items-center gap-1">
            <span class="text-purple-300">😈</span>
            <span class="text-[8px] sm:text-xs text-[var(--color-landing-text-secondary)]">邪</span>
            <span class="font-bold text-purple-300">{@game_state[:player_evil] || 0}</span>
          </div>
        </div>
        
    <!-- 今年の方針 -->
        <%= if @game_state[:current_policy] do %>
          <div class="flex items-center justify-center gap-2 mt-2 pt-2 border-t border-white/10">
            <span class="text-[8px] sm:text-xs text-[var(--color-landing-text-secondary)]">
              📜 今年の方針:
            </span>
            <span class={"text-xs font-bold #{policy_color(@game_state[:current_policy])}"}>
              {policy_name(@game_state[:current_policy])}
            </span>
          </div>
        <% end %>
      </div>
      
    <!-- Chat Panel (hidden by default) -->
      <div
        id="chat-panel"
        class="hidden bg-[rgba(15,20,25,0.95)] border-b border-[var(--color-landing-gold)]/20 px-4 py-3 max-h-48 overflow-y-auto"
      >
        <div id="chat-messages" phx-update="stream" class="space-y-2 mb-3">
          <div
            :for={{id, msg} <- @streams.chat_messages}
            id={id}
            class={"text-xs rounded p-2 #{if Map.get(msg, :is_ai), do: "bg-purple-500/20 border-l-2 border-purple-400", else: "bg-white/5"}"}
          >
            <%= if Map.get(msg, :is_ai) do %>
              <span class="text-purple-300">
                {msg.content || msg.body}
              </span>
            <% else %>
              <span class="font-semibold text-[var(--color-landing-gold)]">
                {msg.user_email || msg.author}:
              </span>
              <span class="text-[var(--color-landing-text-primary)] ml-1">
                {msg.content || msg.body}
              </span>
            <% end %>
          </div>
        </div>
        <.form for={@chat_form} id="chat-form" phx-submit="send_chat" class="flex gap-2">
          <input
            type="text"
            name={@chat_form[:body].name}
            placeholder="メッセージ..."
            class="flex-1 bg-white/10 border border-white/20 rounded px-3 py-1 text-sm text-[var(--color-landing-text-primary)]"
          />
          <button type="submit" class="px-3 py-1 bg-shu text-washi rounded text-sm">送信</button>
        </.form>
      </div>
      
    <!-- Main Content - Desktop Only -->
      <main class="hidden sm:flex flex-1 overflow-hidden">
        <!-- AI Chat Panel - Desktop Only (Left Side) -->
        <aside class="hidden lg:flex flex-col w-72 xl:w-80 bg-[rgba(15,20,25,0.95)] border-r border-purple-500/30">
          <div class="p-3 border-b border-purple-500/30">
            <h3 class="text-sm font-bold text-purple-300 flex items-center gap-2">
              <span>🤖</span>
              <span>AIプレイヤーの会話</span>
            </h3>
          </div>
          <div id="ai-chat-desktop" phx-update="stream" class="flex-1 overflow-y-auto p-3 space-y-2">
            <div
              :for={{id, msg} <- @streams.chat_messages}
              :if={Map.get(msg, :is_ai)}
              id={"desktop-#{id}"}
              class="text-xs bg-purple-500/20 border-l-2 border-purple-400 rounded p-2 animate-fade-in"
            >
              <span class="text-purple-200">{msg.content || msg.body}</span>
            </div>
          </div>
          <div class="p-3 border-t border-purple-500/30 text-[10px] text-purple-400/60 text-center">
            Claude AI による思考・会話
          </div>
        </aside>
        
    <!-- Main Game Area - Extra bottom padding on mobile for fixed hand -->
        <div
          class="flex-1 flex flex-col items-center justify-start p-1 sm:p-4 overflow-y-auto pb-48 sm:pb-4"
          style="padding-bottom: calc(12rem + var(--safe-bottom))"
        >
          <!-- Player List - Hidden on mobile, shown on larger screens -->
          <div class="hidden sm:block w-full max-w-2xl mb-4">
            <div class="flex flex-wrap justify-center gap-2">
              <%= for player <- @players do %>
                <div class={"px-3 py-1 rounded text-xs #{if player.is_ai, do: "bg-purple-500/20 text-purple-300", else: "bg-blue-500/20 text-blue-300"}"}>
                  <%= if player.is_ai do %>
                    🤖 {player.name || player.ai_name}
                  <% else %>
                    👤 あなた
                  <% end %>
                  <span class="ml-1 text-[var(--color-landing-gold)]">φ{player.akasha}</span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Waiting State -->
          <%= if @game_status == :waiting || @game_status == "waiting" do %>
            <div class="text-center space-y-4">
              <h2 class="text-xl font-bold text-[var(--color-landing-pale)]">プレイヤー待機中</h2>
              <div class="text-sm text-[var(--color-landing-text-secondary)]">
                {length(@players)} / 4 人
              </div>
              <%= if @can_start do %>
                <button
                  class="px-6 py-2 bg-shu text-washi rounded font-bold"
                  phx-click="execute_action"
                  phx-value-action="start_game"
                >
                  ゲーム開始
                </button>
              <% end %>
            </div>
          <% end %>
          
    <!-- 神議り (Kami Hakari) Phase - 方針を決める -->
          <%= if @current_phase in ["kami_hakari", :kami_hakari] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full max-w-md px-4 animate-fade-in">
              <div class="text-center mb-6">
                <div class="text-4xl mb-2">⛩️</div>
                <h2 class="text-xl sm:text-2xl font-bold text-[var(--color-landing-gold)] tracking-[0.2em]">
                  神議り
                </h2>
                <p class="text-xs sm:text-sm text-[var(--color-landing-text-secondary)] mt-2">
                  今年の方針を決めましょう
                </p>
              </div>
              
    <!-- 方針選択カード -->
              <div class="grid grid-cols-2 gap-3">
                <!-- 森優先 -->
                <button
                  phx-click="set_policy"
                  phx-value-policy="forest"
                  class="p-4 rounded-lg border-2 border-matsu/40 bg-matsu/10 hover:bg-matsu/20 hover:border-matsu transition-all active:scale-95"
                >
                  <div class="text-2xl mb-1">🌲</div>
                  <div class="text-sm font-bold text-matsu">森優先</div>
                  <div class="text-[10px] text-[var(--color-landing-text-secondary)] mt-1">
                    自然を守る年に
                  </div>
                </button>
                
    <!-- 文化優先 -->
                <button
                  phx-click="set_policy"
                  phx-value-policy="culture"
                  class="p-4 rounded-lg border-2 border-sakura/40 bg-sakura/10 hover:bg-sakura/20 hover:border-sakura transition-all active:scale-95"
                >
                  <div class="text-2xl mb-1">🎭</div>
                  <div class="text-sm font-bold text-sakura">文化優先</div>
                  <div class="text-[10px] text-[var(--color-landing-text-secondary)] mt-1">
                    伝統を育む年に
                  </div>
                </button>
                
    <!-- コミュニティ優先 -->
                <button
                  phx-click="set_policy"
                  phx-value-policy="community"
                  class="p-4 rounded-lg border-2 border-kohaku/40 bg-kohaku/10 hover:bg-kohaku/20 hover:border-kohaku transition-all active:scale-95"
                >
                  <div class="text-2xl mb-1">🤝</div>
                  <div class="text-sm font-bold text-kohaku">絆優先</div>
                  <div class="text-[10px] text-[var(--color-landing-text-secondary)] mt-1">
                    つながりを深める年に
                  </div>
                </button>
                
    <!-- 祓い優先 -->
                <button
                  phx-click="set_policy"
                  phx-value-policy="purify"
                  class="p-4 rounded-lg border-2 border-purple-400/40 bg-purple-900/10 hover:bg-purple-900/20 hover:border-purple-400 transition-all active:scale-95"
                >
                  <div class="text-2xl mb-1">✨</div>
                  <div class="text-sm font-bold text-purple-300">祓い優先</div>
                  <div class="text-[10px] text-[var(--color-landing-text-secondary)] mt-1">
                    邪気を清める年に
                  </div>
                </button>
              </div>

              <div class="mt-4 text-center text-xs text-[var(--color-landing-text-secondary)]">
                ⚠️ 方針に反する行動をすると邪気が溜まります
              </div>

              <div class="mt-3 text-center text-xs text-[var(--color-landing-text-secondary)]">
                自動進行まで:
                <span class="text-[var(--color-landing-gold)] font-bold">{@phase_countdown}秒</span>
              </div>
            </div>
          <% end %>
          
    <!-- 人代フェイズ (Hitoyo Phase) - 人代カード表示 -->
          <%= if @current_phase in ["hitoyo", :hitoyo, "event", :event] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full max-w-md px-4 animate-fade-in">
              <div class="text-center mb-6">
                <div class="text-4xl mb-2">👻</div>
                <h2 class="text-xl sm:text-2xl font-bold text-purple-400 tracking-[0.2em]">人代</h2>
                <p class="text-xs sm:text-sm text-[var(--color-landing-text-secondary)] mt-2">
                  現代社会の流れが世界に影響を与える
                </p>
              </div>
              
    <!-- 邪気レベルによるカード枚数 -->
              <div class="bg-purple-900/20 border border-purple-500/30 rounded-lg p-4 mb-4">
                <div class="flex items-center justify-between mb-3">
                  <span class="text-sm text-[var(--color-landing-text-secondary)]">邪気レベル</span>
                  <span class="text-lg font-bold text-purple-300">
                    {@game_state[:evil_pool] || 0}
                  </span>
                </div>
                <div class="text-xs text-[var(--color-landing-text-secondary)]">
                  <%= cond do %>
                    <% (@game_state[:evil_pool] || 0) <= 2 -> %>
                      邪気0-2: 人代カード1枚
                    <% (@game_state[:evil_pool] || 0) <= 5 -> %>
                      邪気3-5: 人代カード2枚
                    <% true -> %>
                      邪気6-8: 人代カード3枚
                  <% end %>
                </div>
              </div>
              
    <!-- 引かれた人代カードを表示 -->
              <%= if @drawn_hitoyo_cards != [] do %>
                <div class="space-y-3 mb-4">
                  <%= for card <- @drawn_hitoyo_cards do %>
                    <div class="bg-gray-800/80 border border-purple-500/50 rounded-lg p-3 shadow-lg">
                      <div class="flex items-start gap-3">
                        <div class="text-2xl">
                          <%= case card.category do %>
                            <% :env_destruction -> %>
                              💀
                            <% :culture_decline -> %>
                              📉
                            <% :social_crisis -> %>
                              ⚠️
                            <% :blessing -> %>
                              ✨
                            <% _ -> %>
                              🎴
                          <% end %>
                        </div>
                        <div class="flex-1">
                          <div class="font-bold text-purple-300 text-sm">{card.name}</div>
                          <div class="text-xs text-[var(--color-landing-text-secondary)] mt-1">
                            {card.description}
                          </div>
                          <%= if card.effect && map_size(card.effect) > 0 do %>
                            <div class="flex flex-wrap gap-2 mt-2">
                              <%= if card.effect[:forest] && card.effect[:forest] != 0 do %>
                                <span class={"text-xs px-2 py-0.5 rounded #{if card.effect[:forest] > 0, do: "bg-green-500/20 text-green-400", else: "bg-red-500/20 text-red-400"}"}>
                                  森 {if card.effect[:forest] > 0, do: "+", else: ""}{card.effect[
                                    :forest
                                  ]}
                                </span>
                              <% end %>
                              <%= if card.effect[:culture] && card.effect[:culture] != 0 do %>
                                <span class={"text-xs px-2 py-0.5 rounded #{if card.effect[:culture] > 0, do: "bg-pink-500/20 text-pink-400", else: "bg-red-500/20 text-red-400"}"}>
                                  文化 {if card.effect[:culture] > 0, do: "+", else: ""}{card.effect[
                                    :culture
                                  ]}
                                </span>
                              <% end %>
                              <%= if card.effect[:social] && card.effect[:social] != 0 do %>
                                <span class={"text-xs px-2 py-0.5 rounded #{if card.effect[:social] > 0, do: "bg-yellow-500/20 text-yellow-400", else: "bg-red-500/20 text-red-400"}"}>
                                  社会 {if card.effect[:social] > 0, do: "+", else: ""}{card.effect[
                                    :social
                                  ]}
                                </span>
                              <% end %>
                              <%= if card.effect[:jaki] && card.effect[:jaki] != 0 do %>
                                <span class={"text-xs px-2 py-0.5 rounded #{if card.effect[:jaki] > 0, do: "bg-purple-500/20 text-purple-400", else: "bg-blue-500/20 text-blue-400"}"}>
                                  邪気 {if card.effect[:jaki] > 0, do: "+", else: ""}{card.effect[:jaki]}
                                </span>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center text-sm text-[var(--color-landing-text-secondary)] mb-4">
                  <div>🎴 人代カードを読み込み中...</div>
                </div>
              <% end %>
              
    <!-- 処理ボタン（30秒で自動進行） -->
              <div class="space-y-2">
                <button
                  phx-click="advance_hitoyo_phase"
                  class="w-full py-3 bg-purple-600 text-white rounded-lg font-bold hover:bg-purple-700 active:scale-98 transition-all"
                >
                  確認して次へ進む
                </button>
                <div class="text-center text-xs text-[var(--color-landing-text-secondary)]">
                  自動進行まで: <span class="text-purple-400 font-bold">{@phase_countdown}秒</span>
                </div>
              </div>
            </div>
          <% end %>
          
    <!-- Event Phase (Legacy - now part of Hitoyo) -->
          <%= if false && @current_phase in ["event", :event] && @current_event && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full max-w-md animate-fade-in">
              <.event_card
                title={@current_event[:title] || @current_event["title"] || "イベント"}
                description={@current_event[:description] || @current_event["description"] || ""}
                effect={@current_event[:effect] || @current_event["effect"] || %{}}
                category={@current_event[:category] || @current_event["category"] || :neutral}
              />
              <div class="mt-4 text-center text-xs text-[var(--color-landing-text-secondary)]">
                ⏳ AIが自動でイベントを処理中...
              </div>
            </div>
          <% end %>
          
    <!-- 営み (Itonami) Phase: Show current player info - Mobile Optimized -->
          <%= if @current_phase in ["itonami", :itonami, "action", :action] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full px-2">
              <!-- Mobile: Very compact single line -->
              <div class="sm:hidden flex items-center justify-between bg-white/5 rounded-lg px-3 py-2">
                <div class="flex items-center gap-2">
                  <span class="text-[var(--color-landing-gold)] text-sm font-bold">アクション</span>
                  <span class="text-[10px] text-[var(--color-landing-text-secondary)]">
                    {length(@action_logs)}/{length(@players)}
                  </span>
                </div>
                <%= if current_player_turn?(@game_state, @user_id) do %>
                  <span class="text-matsu text-xs font-bold">▼ カードを選択</span>
                <% else %>
                  <span class="text-xs text-[var(--color-landing-text-secondary)]">🤖 AI実行中...</span>
                <% end %>
              </div>
              
    <!-- Desktop: Full display -->
              <div class="hidden sm:block text-center mb-4 space-y-2">
                <div class="text-lg font-bold text-[var(--color-landing-gold)]">アクションフェーズ</div>
                <%= if current_player_turn?(@game_state, @user_id) do %>
                  <div class="text-matsu font-bold">カードを選んでください</div>
                <% else %>
                  <div class="text-[var(--color-landing-text-secondary)]">
                    🤖 AIがアクション実行中...
                  </div>
                <% end %>
                <!-- Action Progress Summary -->
                <div class="bg-white/5 rounded-lg p-3 max-w-md mx-auto mt-4">
                  <div class="text-xs text-[var(--color-landing-text-secondary)] mb-2">
                    <% acted_player_ids = @action_logs |> Enum.map(& &1.player_id) |> Enum.uniq() %> 完了: {length(
                      acted_player_ids
                    )}/{length(@players)} 人
                  </div>
                  <div class="flex flex-wrap justify-center gap-1">
                    <%= for player <- @players do %>
                      <% has_acted =
                        Enum.any?(@action_logs, fn log ->
                          p =
                            Enum.find(@players, fn pl ->
                              (pl.is_ai && pl.name == log.player_name) ||
                                (!pl.is_ai && log.player_name == "あなた")
                            end)

                          p && p.id == player.id
                        end) %>
                      <div class={"px-2 py-1 rounded text-xs #{if has_acted, do: "bg-green-500/30 text-green-300", else: "bg-gray-500/30 text-gray-400"}"}>
                        {if has_acted, do: "✓", else: "⏳"}
                      </div>
                    <% end %>
                  </div>
                  <%= if length(@action_logs) > 0 do %>
                    <div class="mt-2 pt-2 border-t border-white/10">
                      <% last_log = List.first(@action_logs) %>
                      <div class="text-xs text-[var(--color-landing-pale)]">
                        {if last_log.is_ai, do: "🤖", else: "👤"}
                        <%= case last_log.action_type do %>
                          <% "play_card" -> %>
                            🃏 「{String.slice(last_log.card_name || "カード", 0, 6)}」
                          <% "pass" -> %>
                            ⏭️ パス
                          <% _ -> %>
                            {last_log.action_type}
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- 磨きカード選択パネル (営みフェーズ中に表示) -->
            <%= if @show_migaki_panel do %>
              <div class="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4">
                <div class="bg-[rgba(20,25,35,0.98)] border border-[var(--color-landing-gold)]/30 rounded-xl max-w-lg w-full max-h-[80vh] overflow-hidden">
                  <div class="p-4 border-b border-[var(--color-landing-gold)]/20 flex items-center justify-between">
                    <h3 class="text-lg font-bold text-[var(--color-landing-gold)]">✨ 磨きカード</h3>
                    <button
                      phx-click="toggle_migaki_panel"
                      class="text-[var(--color-landing-text-secondary)] hover:text-white"
                    >
                      ✕
                    </button>
                  </div>
                  <div class="p-4 overflow-y-auto max-h-[60vh] space-y-3">
                    <%= for card <- @migaki_cards do %>
                      <% can_afford = (@game_state[:currency] || 0) >= card.cost %>
                      <button
                        phx-click="use_migaki_card"
                        phx-value-card-id={card.id}
                        disabled={!can_afford}
                        class={"w-full text-left p-3 rounded-lg border transition-all " <>
                        if(can_afford, do: "border-green-500/30 bg-green-900/20 hover:bg-green-900/30", else: "border-gray-500/30 bg-gray-900/20 opacity-50")}
                      >
                        <div class="flex items-center gap-2 mb-1">
                          <span class="text-lg">{migaki_category_emoji(card.category)}</span>
                          <span class="font-bold text-[var(--color-landing-pale)]">{card.name}</span>
                          <span class="ml-auto text-sm text-[var(--color-landing-gold)]">
                            φ{card.cost}
                          </span>
                        </div>
                        <p class="text-xs text-[var(--color-landing-text-secondary)] mb-2">
                          {card.description}
                        </p>
                        <div class="flex flex-wrap gap-1 text-[10px]">
                          <%= if card.effect[:forest] && card.effect[:forest] != 0 do %>
                            <span class="px-1.5 py-0.5 bg-matsu/30 text-matsu rounded">
                              F{if card.effect[:forest] > 0, do: "+", else: ""}{card.effect[:forest]}
                            </span>
                          <% end %>
                          <%= if card.effect[:culture] && card.effect[:culture] != 0 do %>
                            <span class="px-1.5 py-0.5 bg-sakura/30 text-sakura rounded">
                              K{if card.effect[:culture] > 0, do: "+", else: ""}{card.effect[:culture]}
                            </span>
                          <% end %>
                          <%= if card.effect[:social] && card.effect[:social] != 0 do %>
                            <span class="px-1.5 py-0.5 bg-kohaku/30 text-kohaku rounded">
                              S{if card.effect[:social] > 0, do: "+", else: ""}{card.effect[:social]}
                            </span>
                          <% end %>
                          <%= if card.effect[:jaki] && card.effect[:jaki] != 0 do %>
                            <span class="px-1.5 py-0.5 bg-purple-500/30 text-purple-300 rounded">
                              邪気{if card.effect[:jaki] > 0, do: "+", else: ""}{card.effect[:jaki]}
                            </span>
                          <% end %>
                        </div>
                      </button>
                    <% end %>
                  </div>
                  <div class="p-3 border-t border-[var(--color-landing-gold)]/20 text-center">
                    <button
                      phx-click="toggle_migaki_panel"
                      class="px-4 py-2 text-sm bg-white/10 hover:bg-white/20 rounded-lg transition-colors"
                    >
                      閉じる
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
            
    <!-- 磨きカードボタン (営みフェーズ中に表示) -->
            <%= if current_player_turn?(@game_state, @user_id) do %>
              <div class="mt-4 text-center">
                <button
                  phx-click="toggle_migaki_panel"
                  class="px-4 py-2 bg-green-600/30 border border-green-500/50 text-green-300 rounded-lg hover:bg-green-600/40 transition-colors text-sm"
                >
                  ✨ 磨きカードを使う
                </button>
              </div>
            <% end %>
          <% end %>
          
    <!-- Discussion Phase -->
          <%= if @current_phase in ["discussion", :discussion] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="text-center space-y-3">
              <div class="text-lg font-bold text-[var(--color-landing-gold)]">相談フェーズ</div>
              <div class="text-xs text-[var(--color-landing-text-secondary)]">
                🤖 AIプレイヤーは自動で準備完了します
              </div>
              <%= if get_player_ready_status(@players, @user_id) do %>
                <div class="text-matsu">✓ 準備完了</div>
              <% else %>
                <button
                  class="px-4 py-2 bg-matsu text-washi rounded"
                  phx-click="execute_action"
                  phx-value-action="mark_discussion_ready"
                >
                  準備完了
                </button>
              <% end %>
            </div>
          <% end %>
          
    <!-- 呼吸 (Kokyu) Phase - 還流・禊 -->
          <%= if @current_phase in ["kokyu", :kokyu, "breathing", :breathing] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full max-w-md px-4 animate-fade-in">
              <div class="text-center mb-6">
                <div class="text-4xl mb-2">🌬️</div>
                <h2 class="text-xl sm:text-2xl font-bold text-[var(--color-landing-gold)] tracking-[0.2em]">
                  呼吸
                </h2>
                <p class="text-xs sm:text-sm text-[var(--color-landing-text-secondary)] mt-2">
                  空環を巡らせ、邪気を祓う
                </p>
              </div>
              
    <!-- 現在の状態 -->
              <div class="bg-white/5 rounded-lg p-4 mb-4">
                <div class="flex justify-between items-center mb-3">
                  <span class="text-sm text-[var(--color-landing-text-secondary)]">あなたの空環</span>
                  <span class="text-lg font-bold text-[var(--color-landing-gold)]">
                    φ{@game_state[:currency] || 0}
                  </span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-sm text-[var(--color-landing-text-secondary)]">あなたの邪気</span>
                  <span class="text-lg font-bold text-purple-300">
                    😈 {@game_state[:player_evil] || 0}
                  </span>
                </div>
              </div>
              
    <!-- 自動還流の説明 -->
              <%= if (@game_state[:currency] || 0) >= 5 do %>
                <div class="bg-matsu/10 border border-matsu/30 rounded-lg p-4 mb-4">
                  <div class="text-sm text-matsu font-bold mb-2">✨ 自動還流</div>
                  <div class="text-xs text-[var(--color-landing-text-secondary)]">
                    空環が5以上あるため、自動的に1点還流され、邪気が1減ります。
                  </div>
                </div>
              <% else %>
                <div class="bg-white/5 border border-white/10 rounded-lg p-4 mb-4">
                  <div class="text-sm text-[var(--color-landing-text-secondary)]">
                    空環が5未満のため、今回は自動還流はありません。
                  </div>
                </div>
              <% end %>
              
    <!-- 追加還流（任意） -->
              <div class="space-y-2 mb-4">
                <div class="text-sm text-[var(--color-landing-text-secondary)]">追加還流（任意）</div>
                <div class="grid grid-cols-3 gap-2">
                  <button
                    phx-click="voluntary_circulation"
                    phx-value-target="forest"
                    phx-value-amount="1"
                    disabled={(@game_state[:currency] || 0) < 1}
                    class={"p-3 rounded-lg border transition-all #{if (@game_state[:currency] || 0) >= 1, do: "border-matsu/40 bg-matsu/10 hover:bg-matsu/20 active:scale-95", else: "border-white/10 bg-white/5 opacity-50 cursor-not-allowed"}"}
                  >
                    <div class="text-xl">🌲</div>
                    <div class="text-[10px] text-matsu">森へ還流</div>
                  </button>
                  <button
                    phx-click="voluntary_circulation"
                    phx-value-target="culture"
                    phx-value-amount="1"
                    disabled={(@game_state[:currency] || 0) < 1}
                    class={"p-3 rounded-lg border transition-all #{if (@game_state[:currency] || 0) >= 1, do: "border-sakura/40 bg-sakura/10 hover:bg-sakura/20 active:scale-95", else: "border-white/10 bg-white/5 opacity-50 cursor-not-allowed"}"}
                  >
                    <div class="text-xl">🎭</div>
                    <div class="text-[10px] text-sakura">文化へ還流</div>
                  </button>
                  <button
                    phx-click="voluntary_circulation"
                    phx-value-target="social"
                    phx-value-amount="1"
                    disabled={(@game_state[:currency] || 0) < 1}
                    class={"p-3 rounded-lg border transition-all #{if (@game_state[:currency] || 0) >= 1, do: "border-kohaku/40 bg-kohaku/10 hover:bg-kohaku/20 active:scale-95", else: "border-white/10 bg-white/5 opacity-50 cursor-not-allowed"}"}
                  >
                    <div class="text-xl">🤝</div>
                    <div class="text-[10px] text-kohaku">絆へ還流</div>
                  </button>
                </div>
              </div>
              
    <!-- 次へ進むボタン（30秒で自動進行） -->
              <div class="space-y-2">
                <button
                  phx-click="advance_breathing_phase"
                  class="w-full py-3 bg-[var(--color-landing-gold)] text-[var(--color-landing-bg)] rounded-lg font-bold hover:opacity-90 active:scale-98 transition-all"
                >
                  呼吸を終える
                </button>
                <div class="text-center text-xs text-[var(--color-landing-text-secondary)]">
                  自動進行まで:
                  <span class="text-[var(--color-landing-gold)] font-bold">{@phase_countdown}秒</span>
                </div>
              </div>
            </div>
          <% end %>
          
    <!-- 結び (Musuhi) Phase - 感謝と称号 -->
          <%= if @current_phase in ["musuhi", :musuhi] && @game_status in ["active", :active, "playing", :playing] do %>
            <div class="w-full max-w-md px-4 animate-fade-in">
              <div class="text-center mb-6">
                <div class="text-4xl mb-2">🎋</div>
                <h2 class="text-xl sm:text-2xl font-bold text-[var(--color-landing-gold)] tracking-[0.2em]">
                  結び
                </h2>
                <p class="text-xs sm:text-sm text-[var(--color-landing-text-secondary)] mt-2">
                  今年を振り返り、感謝を伝える
                </p>
              </div>
              
    <!-- 今年のまとめ -->
              <div class="bg-white/5 rounded-lg p-4 mb-4">
                <div class="text-sm text-[var(--color-landing-gold)] font-bold mb-3">📊 今年の結果</div>
                <div class="grid grid-cols-3 gap-2 text-center">
                  <div class="p-2 bg-matsu/10 rounded">
                    <div class="text-lg font-bold text-matsu">{@game_state.forest}</div>
                    <div class="text-[10px] text-matsu/70">🌲 森</div>
                  </div>
                  <div class="p-2 bg-sakura/10 rounded">
                    <div class="text-lg font-bold text-sakura">{@game_state[:culture] || 0}</div>
                    <div class="text-[10px] text-sakura/70">🎭 文化</div>
                  </div>
                  <div class="p-2 bg-kohaku/10 rounded">
                    <div class="text-lg font-bold text-kohaku">{@game_state[:social] || 0}</div>
                    <div class="text-[10px] text-kohaku/70">🤝 絆</div>
                  </div>
                </div>
                <div class="mt-3 text-center">
                  <div class="text-2xl font-bold text-[var(--color-landing-gold)]">
                    L = {life_index(@game_state)}
                  </div>
                  <div class="text-xs text-[var(--color-landing-text-secondary)]">生命指数</div>
                </div>
              </div>
              
    <!-- オロチ警告 -->
              <%= if (@game_state[:orochi_level] || 0) > 0 do %>
                <div class="bg-shu/10 border border-shu/30 rounded-lg p-4 mb-4">
                  <div class="flex items-center gap-2 text-shu font-bold mb-2">
                    <span class="text-xl">🐍</span>
                    <span>八岐大蛇 Lv.{@game_state[:orochi_level]}</span>
                  </div>
                  <div class="text-xs text-[var(--color-landing-text-secondary)]">
                    <%= case @game_state[:orochi_level] do %>
                      <% 1 -> %>
                        来年、森に-1のペナルティが発生します
                      <% 2 -> %>
                        来年、文化に-1のペナルティが発生します
                      <% 3 -> %>
                        来年、絆に-1のペナルティが発生します
                      <% _ -> %>
                    <% end %>
                  </div>
                </div>
              <% end %>
              
    <!-- 称号表示（将来拡張） -->
              <div class="text-center text-xs text-[var(--color-landing-text-secondary)] mb-4">
                🏷️ 称号システムは今後実装予定
              </div>
              
    <!-- 次の年へ進む（30秒で自動進行） -->
              <div class="space-y-2">
                <button
                  phx-click="advance_musuhi_phase"
                  class="w-full py-3 bg-[var(--color-landing-gold)] text-[var(--color-landing-bg)] rounded-lg font-bold hover:opacity-90 active:scale-98 transition-all"
                >
                  <%= if @game_state.turn >= 20 do %>
                    最終結果を見る
                  <% else %>
                    次の年へ（{@game_state.turn + 1}年目）
                  <% end %>
                </button>
                <div class="text-center text-xs text-[var(--color-landing-text-secondary)]">
                  自動進行まで:
                  <span class="text-[var(--color-landing-gold)] font-bold">{@phase_countdown}秒</span>
                </div>
              </div>
            </div>
          <% end %>
          
    <!-- Game End Screen -->
          <%= if @game_status in ["completed", :completed, "failed", :failed, "won", :won, "lost", :lost] do %>
            <div class="text-center space-y-4">
              <h2 class="text-2xl font-bold text-[var(--color-landing-gold)]">
                {if @game_status in ["completed", :completed], do: "ゲームクリア！", else: "ゲームオーバー"}
              </h2>
              <div class="text-[var(--color-landing-text-secondary)]">
                最終生命指数: {life_index(@game_state)}
              </div>
              <.link
                navigate={~p"/lobby"}
                class="inline-block px-6 py-2 bg-shu text-washi rounded font-bold"
              >
                ロビーに戻る
              </.link>
            </div>
          <% end %>
        </div>
      </main>
      
    <!-- Action Log Toggle Button - Mobile: Above fixed hand, Desktop: Side -->
      <button
        phx-click={JS.toggle(to: "#action-log-panel")}
        class="lg:hidden fixed right-2 bottom-[40vh] z-50 w-10 h-10 flex items-center justify-center bg-[rgba(15,20,25,0.95)] border border-[var(--color-landing-gold)]/40 rounded-full text-[var(--color-landing-gold)] hover:bg-[rgba(25,30,35,0.95)] shadow-lg"
        aria-label="アクションログを表示"
      >
        <span class="text-sm">📋</span>
        <%= if length(@action_logs) > 0 do %>
          <span class="absolute -top-1 -right-1 w-4 h-4 bg-shu rounded-full text-[8px] text-white flex items-center justify-center">
            {length(@action_logs)}
          </span>
        <% end %>
      </button>
      
    <!-- Action Log Panel - Mobile: Bottom sheet, Desktop: Side panel -->
      <aside
        id="action-log-panel"
        class="fixed z-30 hidden lg:flex
        max-lg:inset-x-0 max-lg:bottom-0 max-lg:rounded-t-xl max-lg:max-h-[50vh]
        lg:right-0 lg:top-12 lg:bottom-24 lg:w-64
        bg-[rgba(15,20,25,0.98)] border-t lg:border-l border-[var(--color-landing-gold)]/20 overflow-hidden flex-col"
      >
        <!-- Header -->
        <div class="px-3 py-2 border-b border-[var(--color-landing-gold)]/20 flex items-center justify-between">
          <h3 class="text-sm font-bold text-[var(--color-landing-gold)]">
            📋 ターン {String.pad_leading(Integer.to_string(@game_state.turn), 2, "0")}
          </h3>
          <button
            phx-click={JS.toggle(to: "#action-log-panel")}
            class="lg:hidden w-8 h-8 flex items-center justify-center text-[var(--color-landing-text-secondary)] hover:text-white rounded-full hover:bg-white/10"
          >
            <span class="text-lg">✕</span>
          </button>
        </div>
        <!-- Log entries -->
        <div class="flex-1 overflow-y-auto p-2 space-y-1.5">
          <%= if length(@action_logs) == 0 do %>
            <div class="text-xs text-[var(--color-landing-text-secondary)] text-center py-4">
              アクションなし
            </div>
          <% else %>
            <%= for log <- @action_logs do %>
              <div class={"p-2 rounded-lg text-xs flex items-center gap-2 #{if log.is_ai, do: "bg-blue-900/30 border border-blue-500/30", else: "bg-green-900/30 border border-green-500/30"}"}>
                <span class={
                  if log.is_ai, do: "text-blue-400 text-base", else: "text-green-400 text-base"
                }>
                  {if log.is_ai, do: "🤖", else: "👤"}
                </span>
                <div class="flex-1 min-w-0">
                  <div class="font-bold text-[var(--color-landing-pale)] truncate">
                    {log.player_name || "不明"}
                  </div>
                  <div class="text-[var(--color-landing-text-secondary)] truncate">
                    <%= case log.action_type do %>
                      <% "play_card" -> %>
                        🃏 {log.card_name || "カード"}
                      <% "play_card_with_talents" -> %>
                        ✨ {log.card_name || "カード"}
                      <% "pass" -> %>
                        ⏭️ パス
                      <% _ -> %>
                        {log.action_type}
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
        <!-- Player status - Mobile: Horizontal, Desktop: Vertical -->
        <div class="px-3 py-2 border-t border-[var(--color-landing-gold)]/20 bg-black/20">
          <div class="flex lg:flex-col gap-2 lg:gap-1 overflow-x-auto lg:overflow-visible">
            <%= for player <- @players do %>
              <div class={"flex items-center gap-1.5 px-2 py-1 rounded text-xs whitespace-nowrap #{if player.is_ai, do: "bg-blue-900/20", else: "bg-green-900/20"}"}>
                <span class={if player.is_ai, do: "text-blue-400", else: "text-green-400"}>
                  {if player.is_ai, do: "🤖", else: "👤"}
                </span>
                <span class="hidden lg:inline text-[var(--color-landing-pale)] truncate max-w-[80px]">
                  {if player.is_ai, do: String.slice(player.name || "", 0, 4), else: "あなた"}
                </span>
                <span class="text-[var(--color-landing-gold)] font-bold">φ{player.akasha}</span>
              </div>
            <% end %>
          </div>
        </div>
      </aside>
      
    <!-- Bottom Hand - Desktop Only -->
      <div
        class="hidden sm:block bg-[rgba(15,20,25,0.98)] border-t border-[var(--color-landing-gold)]/30 p-3"
      >
        <!-- Header for hand section -->
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs text-[var(--color-landing-text-secondary)]">
            🎴 手札 ({length(@hand_cards)}枚)
          </span>
          <%= if @current_phase == "action" do %>
            <span class="text-xs text-[var(--color-landing-gold)]">
              カードを選んでアクションを実行
            </span>
          <% end %>
        </div>

        <%= if Enum.empty?(@hand_cards) do %>
          <!-- Empty state message -->
          <div class="flex flex-col items-center justify-center py-4 text-center">
            <span class="text-2xl mb-2">🃏</span>
            <p class="text-sm text-[var(--color-landing-text-secondary)]">
              <%= cond do %>
                <% @current_phase == "action" && @game_status in ["playing", "active"] -> %>
                  AIがアクションを実行中です...
                <% @current_phase == "event" -> %>
                  イベントフェーズ中
                <% @current_phase in ["hitoyo", "itonami"] -> %>
                  一夜フェーズ中
                <% true -> %>
                  使用可能なカードがありません
              <% end %>
            </p>
          </div>
        <% else %>
          <!-- Unified: Simple list view -->
          <div class="max-sm:flex max-sm:gap-2 max-sm:overflow-x-auto max-sm:snap-x max-sm:snap-mandatory max-sm:-mx-2 max-sm:px-2 sm:space-y-1.5 sm:max-h-[35vh] sm:overflow-y-auto">
            <%= for card <- @hand_cards do %>
              <% can_afford =
                (@game_state[:currency] || @game_state.currency || 0) >= (card.cost_akasha || 0) %>
              <button
                phx-click="select_card"
                phx-value-card-id={card.id}
                disabled={!can_afford}
                class={"w-full flex items-center justify-between p-3 rounded-lg transition-all active:scale-98 " <>
                  if(@selected_card_id == card.id, do: "bg-[var(--color-landing-gold)]/20 ring-2 ring-[var(--color-landing-gold)] ", else: "bg-white/5 ") <>
                  if(can_afford, do: "hover:bg-white/10", else: "opacity-40") <>
                  " max-sm:min-w-[220px] max-sm:snap-start max-sm:h-[84px]"}
              >
                <div class="flex items-center gap-2">
                  <span class={"text-lg " <> card_category_emoji(card.category)}></span>
                  <span class="text-sm font-medium text-[var(--color-landing-pale)] line-clamp-1">
                    {card.title}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-xs text-[var(--color-landing-gold)]">
                    φ{card.cost_akasha || card.cost}
                  </span>
                  <span class="text-[var(--color-landing-text-secondary)]">›</span>
                </div>
              </button>
            <% end %>
          </div>
          
    <!-- Desktop: Traditional card view - REMOVED -->
        <% end %>
      </div>
      
    <!-- Talent Selector Modal - Mobile Optimized -->
      <%= if @show_talent_selector && @talent_selector_card_id do %>
        <div
          class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm"
          phx-click="close_talent_selector"
          role="dialog"
          aria-modal="true"
        >
          <div
            class="relative bg-washi border-t-4 sm:border-4 border-double border-kin rounded-t-lg sm:rounded-lg shadow-2xl max-w-lg w-full mx-0 sm:mx-4 max-h-[80vh] overflow-y-auto"
            phx-click-away="close_talent_selector"
          >
            <button
              class="absolute top-2 sm:top-4 right-2 sm:right-4 w-6 h-6 sm:w-8 sm:h-8 bg-sumi/20 text-sumi rounded-full flex items-center justify-center hover:bg-sumi/30 transition-colors"
              phx-click="close_talent_selector"
              aria-label="モーダルを閉じる"
            >
              <span class="text-sm sm:text-lg font-bold">×</span>
            </button>
            <div class="p-3 sm:p-6">
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
    # Debug logging
    require Logger
    Logger.info("[DEBUG] select_card event: card_id=#{inspect(card_id)}, hand_cards_count=#{length(socket.assigns.hand_cards)}")
    Logger.info("[DEBUG] hand_cards ids: #{inspect(Enum.map(socket.assigns.hand_cards, & &1.id))}")

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

  # カード詳細画面から「使用する」ボタンをクリック
  def handle_event("use_card_from_detail", %{"card-id" => card_id}, socket) do
    # カード詳細モーダルを閉じて、アクション確認モーダルを開く
    card = Enum.find(socket.assigns.hand_cards, &(&1.id == card_id))

    if card do
      # タグがあればタレントセレクターを表示、なければ直接確認画面へ
      if card[:tags] && length(card[:tags]) > 0 do
        {:noreply,
         socket
         |> assign(:show_card_detail, false)
         |> assign(:detail_card, nil)
         |> assign(:show_talent_selector, true)
         |> assign(:talent_selector_card_id, card_id)
         |> assign(:selected_talents_for_card, [])}
      else
        {:noreply,
         socket
         |> assign(:show_card_detail, false)
         |> assign(:detail_card, nil)
         |> assign(:show_action_confirm, true)
         |> assign(:confirm_card_id, card_id)}
      end
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
        # アクションカードを取得（キャッシュから）
        action_card = Shinkanki.CardCache.get_action_card(card_id)

        if is_nil(action_card) do
          {:noreply, put_flash(socket, :error, "カードが見つかりませんでした")}
        else
          # タレントが選択されていれば、タレント付きで実行
          result =
            if Enum.empty?(selected_talents) do
              Games.execute_action_card(player, action_card, game_session)
            else
              Games.execute_action_card_with_talents(
                player,
                action_card,
                game_session,
                selected_talents
              )
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
          end
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

  # ============================================================================
  # 連携（Renkei）イベントハンドラ
  # ============================================================================

  # 連携カードの提案を開始する
  def handle_event("initiate_renkei", %{"renkei-id" => renkei_id}, socket) do
    room_id = socket.assigns.room_id
    player_id = socket.assigns.player_id

    case Shinkanki.GameServer.initiate_renkei(room_id, player_id, renkei_id) do
      {:ok, _game} ->
        # 成功 - pending_renkei を更新
        pending = Shinkanki.GameServer.get_pending_renkei(room_id)

        {:noreply,
         socket
         |> assign(:pending_renkei, pending)
         |> put_flash(:info, "連携を提案しました。他のプレイヤーの参加を待っています...")}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :error, "この連携は既に提案されています")}

      {:error, :insufficient_cost} ->
        {:noreply, put_flash(socket, :error, "アカーシャ通貨が足りません")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "連携提案エラー: #{inspect(reason)}")}
    end
  end

  # 他プレイヤーが提案した連携に参加する
  def handle_event("join_renkei", %{"renkei-id" => renkei_id}, socket) do
    room_id = socket.assigns.room_id
    player_id = socket.assigns.player_id

    case Shinkanki.GameServer.join_renkei(room_id, player_id, renkei_id) do
      {:ok, _game} ->
        # 成功 - pending_renkei を更新
        pending = Shinkanki.GameServer.get_pending_renkei(room_id)

        {:noreply,
         socket
         |> assign(:pending_renkei, pending)
         |> put_flash(:info, "連携に参加しました！")}

      {:error, :already_joined} ->
        {:noreply, put_flash(socket, :error, "既に参加しています")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "この連携は存在しません")}

      {:error, :insufficient_cost} ->
        {:noreply, put_flash(socket, :error, "アカーシャ通貨が足りません")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "連携参加エラー: #{inspect(reason)}")}
    end
  end

  # 自分が提案した連携をキャンセルする
  def handle_event("cancel_renkei", %{"renkei-id" => renkei_id}, socket) do
    room_id = socket.assigns.room_id
    player_id = socket.assigns.player_id

    case Shinkanki.GameServer.cancel_renkei(room_id, player_id, renkei_id) do
      {:ok, _game} ->
        # 成功 - pending_renkei を更新
        pending = Shinkanki.GameServer.get_pending_renkei(room_id)

        {:noreply,
         socket
         |> assign(:pending_renkei, pending)
         |> put_flash(:info, "連携をキャンセルしました")}

      {:error, :not_initiator} ->
        {:noreply, put_flash(socket, :error, "提案者のみキャンセルできます")}

      {:error, :not_pending} ->
        {:noreply, put_flash(socket, :error, "この連携は存在しません")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "連携キャンセルエラー: #{inspect(reason)}")}
    end
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
     |> assign(:game_status, "playing")
     |> assign(:show_ending, false)
     |> assign(:hand_cards, mock_hand_cards())
     |> assign(:current_phase, "event")
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
      # アクションカードを取得（キャッシュから）
      action_card = Shinkanki.CardCache.get_action_card(card_id)

      if is_nil(action_card) do
        {:noreply, put_flash(socket, :error, "カードが見つかりませんでした")}
      else
        # プレイヤーがまだアクションを実行していないかチェック
        if Games.player_has_acted?(game_session.id, player.id, game_session.turn) do
          toast_id = "toast-#{System.unique_integer([:positive])}"

          new_toast = %{
            id: toast_id,
            kind: :error,
            message: "このターンは既にアクションを実行しました。"
          }

          socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
          Process.send_after(self(), {:remove_toast, toast_id}, 3000)
          {:noreply, socket}
        else
          # アクションカードを実行
          case Games.execute_action_card(player, action_card, game_session) do
            {:ok, _updated_session} ->
              # 全プレイヤーがアクション完了したかチェック（次ターンへの進行）
              Games.check_and_advance_turn(game_session.id)

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
          end
        end
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

  # 神議りフェーズ: 方針を設定
  def handle_event("set_policy", %{"policy" => policy}, socket) do
    game_session = socket.assigns.game_session

    # タイマーをキャンセル
    if socket.assigns[:phase_auto_advance_timer] do
      Process.cancel_timer(socket.assigns.phase_auto_advance_timer)
    end

    case Games.set_policy(game_session.id, policy) do
      {:ok, updated_session} ->
        # 次のフェーズ（イベント）に進む
        case Games.advance_phase(updated_session.id) do
          {:ok, _} ->
            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :info,
              message: "今年の方針「#{policy_name(policy)}」を決定しました"
            }

            # 次のフェーズの自動処理を継続
            Process.send_after(self(), {:ai_auto_action, game_session.id}, 500)

            socket =
              socket
              |> assign(:phase_auto_advance_timer, nil)
              |> assign(:phase_countdown, 30)
              |> update(:toasts, fn toasts -> [new_toast | toasts] end)

            Process.send_after(self(), {:remove_toast, toast_id}, 3000)
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # 呼吸フェーズ: 任意の還流
  def handle_event(
        "voluntary_circulation",
        %{"target" => target, "amount" => amount},
        socket
      ) do
    game_session = socket.assigns.game_session
    user_id = socket.assigns.user_id
    amount = String.to_integer(amount)

    # 現在のプレイヤーを取得
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)

    if player do
      case Games.voluntary_circulation(player, amount, target) do
        {:ok, _updated_player} ->
          toast_id = "toast-#{System.unique_integer([:positive])}"

          target_name =
            case target do
              "forest" -> "森"
              "culture" -> "文化"
              "social" -> "絆"
              _ -> target
            end

          new_toast = %{
            id: toast_id,
            kind: :info,
            message: "#{amount}空環を#{target_name}へ還流しました（邪気-1）"
          }

          socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
          Process.send_after(self(), {:remove_toast, toast_id}, 3000)
          {:noreply, socket}

        {:error, reason} ->
          toast_id = "toast-#{System.unique_integer([:positive])}"

          new_toast = %{
            id: toast_id,
            kind: :error,
            message: "還流に失敗しました: #{reason}"
          }

          socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
          Process.send_after(self(), {:remove_toast, toast_id}, 3000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # 人代フェーズを処理
  def handle_event("advance_hitoyo_phase", _params, socket) do
    game_session = socket.assigns.game_session
    drawn_cards = socket.assigns[:drawn_hitoyo_cards] || []

    # タイマーをキャンセル
    if socket.assigns[:phase_auto_advance_timer] do
      Process.cancel_timer(socket.assigns.phase_auto_advance_timer)
    end

    # すでに引いたカードがある場合はそれを使用、なければ新しく引く
    {hitoyo_cards, _updated_session} =
      if drawn_cards != [] do
        {:ok, session} = Games.apply_drawn_hitoyo_cards(game_session.id, drawn_cards)
        {drawn_cards, session}
      else
        {:ok, session, cards} = Games.execute_hitoyo_phase(game_session.id)
        {cards, session}
      end

    # 引いた人代カードの名前をトーストで表示
    card_names = Enum.map_join(hitoyo_cards, "、", & &1.name)
    toast_id = "toast-#{System.unique_integer([:positive])}"

    new_toast = %{
      id: toast_id,
      kind: :warning,
      message: "人代カード効果適用: #{card_names}"
    }

    # 次のフェーズの自動処理を継続
    Process.send_after(self(), {:ai_auto_action, game_session.id}, 500)

    socket =
      socket
      |> assign(:phase_auto_advance_timer, nil)
      |> assign(:phase_countdown, 30)
      |> assign(:drawn_hitoyo_cards, [])
      |> update(:toasts, fn toasts -> [new_toast | toasts] end)

    Process.send_after(self(), {:remove_toast, toast_id}, 5000)
    {:noreply, socket}
  end

  # 磨きカードパネルの表示切替
  def handle_event("toggle_migaki_panel", _params, socket) do
    {:noreply, assign(socket, :show_migaki_panel, !socket.assigns.show_migaki_panel)}
  end

  # 磨きカードを使用
  def handle_event("use_migaki_card", %{"card-id" => card_id_str}, socket) do
    game_session = socket.assigns.game_session
    user_id = socket.assigns.user_id

    # プレイヤーを取得
    player = Enum.find(game_session.players, fn p -> p.user_id == user_id end)

    if player do
      # 文字列のカードIDをatomに変換
      card_id = String.to_existing_atom(card_id_str)

      case Games.execute_migaki_card(player, card_id, game_session) do
        {:ok, _updated_session} ->
          card = Shinkanki.Card.get_migaki(card_id)
          card_name = if card, do: card.name, else: "磨きカード"

          toast_id = "toast-#{System.unique_integer([:positive])}"

          new_toast = %{
            id: toast_id,
            kind: :success,
            message: "✨ #{card_name}を使用しました"
          }

          socket =
            socket
            |> update(:toasts, fn toasts -> [new_toast | toasts] end)
            |> assign(:show_migaki_panel, false)

          Process.send_after(self(), {:remove_toast, toast_id}, 3000)
          {:noreply, socket}

        {:error, :insufficient_resources} ->
          toast_id = "toast-#{System.unique_integer([:positive])}"

          new_toast = %{
            id: toast_id,
            kind: :error,
            message: "コストが足りません"
          }

          socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
          Process.send_after(self(), {:remove_toast, toast_id}, 3000)
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("advance_breathing_phase", _params, socket) do
    game_session = socket.assigns.game_session

    # タイマーをキャンセル
    if socket.assigns[:phase_auto_advance_timer] do
      Process.cancel_timer(socket.assigns.phase_auto_advance_timer)
    end

    # 呼吸フェーズの処理を実行（新しい関数を使用）
    {:ok, _updated_session} = Games.execute_kokyu_phase(game_session.id)
    # 次のフェーズへ
    Games.advance_phase(game_session.id)

    toast_id = "toast-#{System.unique_integer([:positive])}"

    new_toast = %{
      id: toast_id,
      kind: :info,
      message: "呼吸フェーズを完了しました"
    }

    # 次のフェーズの自動処理を継続
    Process.send_after(self(), {:ai_auto_action, game_session.id}, 500)

    socket =
      socket
      |> assign(:phase_auto_advance_timer, nil)
      |> assign(:phase_countdown, 30)
      |> update(:toasts, fn toasts -> [new_toast | toasts] end)

    Process.send_after(self(), {:remove_toast, toast_id}, 3000)
    {:noreply, socket}
  end

  # 結びフェーズ: 次のフェーズ（年の終わり）へ進む
  def handle_event("advance_musuhi_phase", _params, socket) do
    game_session = socket.assigns.game_session

    # タイマーをキャンセル
    if socket.assigns[:phase_auto_advance_timer] do
      Process.cancel_timer(socket.assigns.phase_auto_advance_timer)
    end

    # 結びフェーズの処理を実行（game_session_idを渡す）
    {:ok, _updated_musuhi} = Games.execute_musuhi_phase(game_session.id)

    # 年の終わりフェーズへ進む
    case Games.advance_phase(game_session.id) do
      {:ok, _} ->
        # 年の終わり処理を実行し、次のターンを開始
        turn = game_session.turn
        result = Games.execute_end_of_turn(game_session.id)

        # 次のフェーズの自動処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session.id}, 500)

        socket =
          socket
          |> assign(:phase_auto_advance_timer, nil)
          |> assign(:phase_countdown, 30)

        case result do
          {:continue, _} ->
            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :info,
              message: "第#{turn}年が終了しました"
            }

            socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
            Process.send_after(self(), {:remove_toast, toast_id}, 3000)
            {:noreply, socket}

          {:game_over, _reason, _final_session} ->
            toast_id = "toast-#{System.unique_integer([:positive])}"

            new_toast = %{
              id: toast_id,
              kind: :info,
              message: "ゲームが終了しました"
            }

            socket = update(socket, :toasts, fn toasts -> [new_toast | toasts] end)
            Process.send_after(self(), {:remove_toast, toast_id}, 3000)
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # Mobile UI: タブ切替
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  # Mobile UI: カードフルスクリーン表示
  def handle_event("show_card_fullscreen", %{"card-id" => card_id}, socket) do
    card = find_card_by_id(socket.assigns.hand_cards, card_id)
    {:noreply, socket |> assign(:show_card_fullscreen, true) |> assign(:fullscreen_card, card)}
  end

  def handle_event("close_card_fullscreen", _params, socket) do
    {:noreply, socket |> assign(:show_card_fullscreen, false) |> assign(:fullscreen_card, nil)}
  end

  def handle_event("use_card_from_fullscreen", %{"card-id" => card_id}, socket) do
    # フルスクリーンを閉じてからカード使用処理
    socket = socket |> assign(:show_card_fullscreen, false) |> assign(:fullscreen_card, nil)
    handle_card_use(socket, card_id)
  end

  defp find_card_by_id(cards, card_id) do
    Enum.find(cards, fn card ->
      to_string(card.id) == to_string(card_id)
    end)
  end

  defp handle_card_use(socket, card_id) do
    # 既存のuse_card処理と同じ: 確認モーダルを表示
    card = Enum.find(socket.assigns.hand_cards, fn c ->
      to_string(c.id) == to_string(card_id)
    end)

    if card do
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

  # GamePubSubからの更新を受け取る（DBベースのGameSession）
  def handle_info({:game_state_updated, %Shinkanki.Games.GameSession{} = game_session}, socket) do
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
      |> assign(:player_talents, [])
      |> assign(:active_projects, [])
      |> assign(:players, get_players_from_session(updated_session))
      |> assign(:player_role, nil)
      |> assign(:show_ending, updated_session.status in ["completed", "failed"])
      |> assign(:game_status, updated_session.status)
      |> assign(:ending_type, nil)
      |> assign(:action_logs, [])

    # AI自動行動をトリガー
    if Enum.any?(updated_session.players, fn p -> p.is_ai end) do
      Process.send_after(self(), {:ai_auto_action, updated_session.id}, 500)
    end

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
    handle_memory_game_state_update(game, socket)
  end

  # タプル形式のメッセージ（Shinkanki.PubSubからの直接ブロードキャスト）
  def handle_info({:game_state_updated, %Shinkanki.Game{} = game}, socket) do
    handle_memory_game_state_update(game, socket)
  end

  def handle_info({:remove_toast, toast_id}, socket) do
    {:noreply,
     update(socket, :toasts, fn toasts -> Enum.reject(toasts, &(&1.id == toast_id)) end)}
  end

  # フェーズ確認用カウントダウン開始
  def handle_info({:start_phase_countdown, game_session_id, phase}, socket) do
    # 既存のタイマーがあればキャンセル
    if socket.assigns[:phase_auto_advance_timer] do
      Process.cancel_timer(socket.assigns.phase_auto_advance_timer)
    end

    # 30秒後に自動進行
    timer_ref = Process.send_after(self(), {:phase_auto_advance, game_session_id, phase}, 30_000)
    # 1秒ごとにカウントダウン更新
    Process.send_after(self(), {:phase_countdown_tick, game_session_id, phase}, 1000)

    socket =
      socket
      |> assign(:phase_auto_advance_timer, timer_ref)
      |> assign(:phase_countdown, 30)

    # 人代フェーズの場合はカードを引いて保存
    socket =
      if phase == "hitoyo" and socket.assigns[:drawn_hitoyo_cards] == [] do
        game_session = Games.get_game_session!(game_session_id)
        jaki_level = game_session.evil_pool
        hitoyo_cards = Shinkanki.Card.draw_hitoyo_cards(jaki_level)
        assign(socket, :drawn_hitoyo_cards, hitoyo_cards)
      else
        socket
      end

    {:noreply, socket}
  end

  # カウントダウン更新（1秒ごと）
  def handle_info({:phase_countdown_tick, game_session_id, phase}, socket) do
    current_countdown = socket.assigns[:phase_countdown] || 0

    if current_countdown > 1 && socket.assigns[:phase_auto_advance_timer] do
      # まだカウントダウン中
      Process.send_after(self(), {:phase_countdown_tick, game_session_id, phase}, 1000)
      {:noreply, assign(socket, :phase_countdown, current_countdown - 1)}
    else
      # カウントダウン終了
      {:noreply, socket}
    end
  end

  # 30秒経過後の自動進行
  def handle_info({:phase_auto_advance, game_session_id, phase}, socket) do
    # タイマーをクリア
    socket = assign(socket, :phase_auto_advance_timer, nil)

    case phase do
      "hitoyo" ->
        # 人代フェーズを自動で完了
        Games.execute_hitoyo_phase(game_session_id)
        # 次のフェーズの処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session_id}, 500)

      "kami_hakari" ->
        # 神議りフェーズを自動で完了（最も低いパラメータを方針に）
        game_session = Games.get_game_session!(game_session_id)
        policy = ai_suggest_policy(game_session)
        Games.set_policy(game_session_id, policy)
        # 次のフェーズの処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session_id}, 500)

      "breathing" ->
        # 呼吸フェーズを自動で完了
        {:ok, _} = Games.execute_kokyu_phase(game_session_id)
        Games.advance_phase(game_session_id)
        # 次のフェーズの処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session_id}, 500)

      "musuhi" ->
        # 結びフェーズを自動で完了
        {:ok, _} = Games.execute_musuhi_phase(game_session_id)
        Games.advance_phase(game_session_id)
        # 次のフェーズの処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session_id}, 500)

      _ ->
        :ok
    end

    {:noreply, assign(socket, :phase_countdown, 30)}
  end

  # AI自動行動をスケジュール（新しい6フェーズシステム対応）
  def handle_info({:ai_auto_action, game_session_id}, socket) do
    # AIが自動で行動を実行
    game_session = Games.get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)
    current_phase = if turn_state, do: turn_state.phase, else: "hitoyo"

    case current_phase do
      # 人代フェーズ: プレイヤーの確認を待つ（30秒で自動進行）
      phase when phase in ["hitoyo", "event"] ->
        # タイマーがなければ開始（30秒カウントダウン）
        if is_nil(socket.assigns[:phase_auto_advance_timer]) do
          send(self(), {:start_phase_countdown, game_session_id, "hitoyo"})
        end

      # 神議りフェーズ: プレイヤーの確認を待つ（30秒で自動進行）
      "kami_hakari" ->
        # タイマーがなければ開始（30秒カウントダウン）
        if is_nil(socket.assigns[:phase_auto_advance_timer]) do
          send(self(), {:start_phase_countdown, game_session_id, "kami_hakari"})
        end

      # 営みフェーズ: AIプレイヤーがアクションを実行
      phase when phase in ["itonami", "action"] ->
        execute_ai_actions_smart(game_session)
        # フェーズが変わったか確認してからスケジュール
        updated_session = Games.get_game_session!(game_session_id)
        updated_turn_state = get_current_turn_state(updated_session)
        new_phase = if updated_turn_state, do: updated_turn_state.phase, else: "action"

        if new_phase != current_phase do
          # 呼吸フェーズに移行：ユーザーが確認できるよう3秒待機
          Process.send_after(self(), {:ai_auto_action, game_session_id}, 3000)
        end

      # 呼吸フェーズ: プレイヤーの確認を待つ（30秒で自動進行）
      phase when phase in ["kokyu", "breathing"] ->
        # タイマーがなければ開始（30秒カウントダウン）
        if is_nil(socket.assigns[:phase_auto_advance_timer]) do
          send(self(), {:start_phase_countdown, game_session_id, "breathing"})
        end

      # 結びフェーズ: プレイヤーの確認を待つ（30秒で自動進行）
      "musuhi" ->
        # タイマーがなければ開始（30秒カウントダウン）
        if is_nil(socket.assigns[:phase_auto_advance_timer]) do
          send(self(), {:start_phase_countdown, game_session_id, "musuhi"})
        end

      # 年送りフェーズ: 自動で次のターンへ
      phase when phase in ["toshiokuri", "end"] ->
        Games.execute_toshiokuri_phase(game_session.id)
        # 次のターン開始後に自動処理を継続
        Process.send_after(self(), {:ai_auto_action, game_session_id}, 2000)

      # 後方互換: discussionフェーズ
      "discussion" ->
        Games.advance_to_action_phase(game_session.id)
        # フェーズが変わったか確認してからスケジュール
        updated_session = Games.get_game_session!(game_session_id)
        updated_turn_state = get_current_turn_state(updated_session)
        new_phase = if updated_turn_state, do: updated_turn_state.phase, else: "discussion"

        if new_phase != current_phase do
          Process.send_after(self(), {:ai_auto_action, game_session_id}, 500)
        end

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  # AIチャットメッセージを受信（Claude AIエージェントからの思考・会話）
  def handle_info(
        {:ai_chat_message, %{player_id: player_id, message: message, timestamp: timestamp}},
        socket
      ) do
    # AIメッセージをチャットストリームに追加
    ai_message = %{
      id: "ai_#{player_id}_#{:erlang.system_time(:millisecond)}",
      user_email: "AI",
      content: message,
      inserted_at: timestamp,
      is_ai: true
    }

    {:noreply, stream(socket, :chat_messages, [ai_message])}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp handle_memory_game_state_update(game, socket) do
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

  # AIが方針を提案（最も低いパラメータを優先）
  defp ai_suggest_policy(game_session) do
    f = game_session.forest
    k = game_session.culture
    s = game_session.social
    evil = game_session.evil_pool

    cond do
      # 邪気が高い場合は浄化優先
      evil >= 5 -> "purify"
      f <= k and f <= s -> "forest"
      k <= f and k <= s -> "culture"
      s <= f and s <= k -> "community"
      true -> Enum.random(["forest", "culture", "community", "purify"])
    end
  end

  # AIプレイヤーのアクションを実行（賢い意思決定版）
  defp execute_ai_actions_smart(game_session) do
    ai_players = Enum.filter(game_session.players, fn p -> p.is_ai end)

    # まだアクションを実行していないAIプレイヤーのみ処理
    Enum.each(ai_players, fn ai_player ->
      unless Games.player_has_acted?(game_session.id, ai_player.id, game_session.turn) do
        turn_state = get_current_turn_state(game_session)
        available_cards = if turn_state, do: turn_state.available_cards || [], else: []

        if Enum.empty?(available_cards) do
          Games.pass_action(game_session.id, ai_player.id)
        else
          # 賢くカードを選択
          card_id = ai_select_best_card(game_session, ai_player, available_cards)
          Games.execute_action_if_not_acted(game_session.id, ai_player.id, card_id)
        end
      end
    end)

    # 全プレイヤー（人間+AI）がアクション完了したかチェック
    Games.check_and_advance_turn(game_session.id)
  end

  # AIがベストなカードを選択（役割とゲーム状況に基づく）
  defp ai_select_best_card(game_session, ai_player, available_card_ids) do
    # カード情報を取得（キャッシュから）
    cards = Shinkanki.CardCache.action_cards_by_ids(available_card_ids)

    if Enum.empty?(cards) do
      Enum.random(available_card_ids)
    else
      # 現在のゲーム状況を分析
      f = game_session.forest
      k = game_session.culture
      s = game_session.social
      evil = game_session.evil_pool
      policy = game_session.current_policy

      # 最も低いパラメータを特定
      {weakest, _value} =
        [{:forest, f}, {:culture, k}, {:social, s}]
        |> Enum.min_by(fn {_key, v} -> v end)

      # 役割に応じた優先カテゴリ
      role_category =
        case ai_player.role do
          "forest_guardian" -> "forest"
          "heritage_weaver" -> "culture"
          "community_keeper" -> "social"
          "akasha_architect" -> "akasha"
          _ -> nil
        end

      # カードをスコアリング
      scored_cards =
        Enum.map(cards, fn card ->
          score = 0

          # 方針と一致するカテゴリは高得点
          score = if policy && card.category == policy, do: score + 3, else: score

          # 役割に合ったカテゴリは高得点
          score = if role_category && card.category == role_category, do: score + 2, else: score

          # 最も低いパラメータを上げるカードは高得点
          score =
            case weakest do
              :forest -> score + (card.effect_forest || 0)
              :culture -> score + (card.effect_culture || 0)
              :social -> score + (card.effect_social || 0)
            end

          # 邪気が高い時は邪気を減らすカードを優先
          evil_delta = Map.get(card, :evil_delta, 0) || 0
          score = if evil >= 5 and evil_delta < 0, do: score + 3, else: score

          # コストが払えるか確認（払えなければ大幅減点）
          score = if ai_player.akasha >= (card.cost_akasha || 0), do: score, else: score - 10

          {card.id, score}
        end)

      # 最高スコアのカードを選択（同点の場合はランダム）
      {best_card_id, _score} =
        scored_cards
        |> Enum.sort_by(fn {_id, score} -> -score end)
        |> List.first()

      best_card_id
    end
  end

  defp life_index(state) do
    forest = state[:forest] || state.forest || 0
    culture = state[:culture] || state.culture || 0
    social = state[:social] || state.social || 0
    forest + culture + social
  end

  # 方針名の取得
  defp policy_name("forest"), do: "森優先"
  defp policy_name("culture"), do: "文化優先"
  defp policy_name("community"), do: "絆優先"
  defp policy_name("purify"), do: "祓い優先"
  defp policy_name(_), do: "未選択"

  # 方針の色
  defp policy_color("forest"), do: "text-green-600"
  defp policy_color("culture"), do: "text-purple-600"
  defp policy_color("community"), do: "text-blue-600"
  defp policy_color("purify"), do: "text-amber-600"
  defp policy_color(_), do: "text-gray-500"

  # 短縮版フェーズ名（モバイル用）
  # 新フェーズ名（shinkanki_rules.xml準拠）
  defp phase_name_short(:hitoyo), do: "人代"
  defp phase_name_short("hitoyo"), do: "人代"
  defp phase_name_short(:kami_hakari), do: "神議"
  defp phase_name_short("kami_hakari"), do: "神議"
  defp phase_name_short(:itonami), do: "営み"
  defp phase_name_short("itonami"), do: "営み"
  defp phase_name_short(:kokyu), do: "呼吸"
  defp phase_name_short("kokyu"), do: "呼吸"
  defp phase_name_short(:musuhi), do: "結び"
  defp phase_name_short("musuhi"), do: "結び"
  defp phase_name_short(:toshiokuri), do: "年送"
  defp phase_name_short("toshiokuri"), do: "年送"
  # 後方互換性
  defp phase_name_short(:event), do: "人代"
  defp phase_name_short("event"), do: "人代"
  defp phase_name_short(:discussion), do: "相談"
  defp phase_name_short("discussion"), do: "相談"
  defp phase_name_short(:action), do: "営み"
  defp phase_name_short("action"), do: "営み"
  defp phase_name_short(:breathing), do: "呼吸"
  defp phase_name_short("breathing"), do: "呼吸"
  defp phase_name_short(:end), do: "年送"
  defp phase_name_short("end"), do: "年送"
  defp phase_name_short(:resolution), do: "解決"
  defp phase_name_short("resolution"), do: "解決"
  defp phase_name_short(_), do: "待機"

  # Mobile game tab content renderer
  defp render_mobile_game_tab(assigns) do
    assigns = assign(assigns, :phase, assigns.current_phase)

    ~H"""
    <!-- Current Phase Info -->
    <div class="bg-white/5 rounded-xl p-4">
      <div class="flex items-center justify-between mb-3">
        <span class="text-lg font-bold text-[var(--color-landing-gold)]">
          {phase_name_short(@phase)}フェーズ
        </span>
        <span class="text-sm text-[var(--color-landing-text-secondary)]">
          ターン {@game_state.turn}/20
        </span>
      </div>

      <%= cond do %>
        <% @phase in ["hitoyo", :hitoyo] -> %>
          <div class="space-y-3">
            <p class="text-sm text-[var(--color-landing-pale)]">
              人代カードが引かれました。効果を確認してください。
            </p>
            <%= if length(@drawn_hitoyo_cards) > 0 do %>
              <div class="space-y-2">
                <%= for card <- @drawn_hitoyo_cards do %>
                  <div class="bg-purple-900/30 border border-purple-500/30 rounded-lg p-3">
                    <div class="font-bold text-purple-300">{card.name}</div>
                    <div class="text-xs text-[var(--color-landing-text-secondary)] mt-1">
                      {card.description}
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
            <button
              phx-click="advance_hitoyo_phase"
              class="w-full py-3 bg-purple-600 text-white rounded-lg font-bold active:scale-95 transition-transform"
            >
              確認して次へ進む
            </button>
          </div>

        <% @phase in ["action", :action, "itonami", :itonami] -> %>
          <div class="space-y-3">
            <p class="text-sm text-[var(--color-landing-pale)]">
              手札タブでカードを選んでアクションを実行してください。
            </p>
            <div class="flex items-center justify-between text-xs">
              <span class="text-[var(--color-landing-text-secondary)]">
                進捗: {length(@action_logs)}/{length(@players)}人完了
              </span>
              <%= if current_player_turn?(@game_state, @user_id) do %>
                <span class="text-matsu font-bold">あなたの番です</span>
              <% else %>
                <span class="text-[var(--color-landing-text-secondary)]">他のプレイヤーを待っています...</span>
              <% end %>
            </div>
          </div>

        <% @phase in ["breathing", :breathing, "kokyu", :kokyu] -> %>
          <div class="space-y-3">
            <p class="text-sm text-[var(--color-landing-pale)]">
              世界が呼吸しています。パラメータが自然回復します。
            </p>
            <button
              phx-click="advance_breathing_phase"
              class="w-full py-3 bg-matsu text-white rounded-lg font-bold active:scale-95 transition-transform"
            >
              呼吸フェーズを進める
            </button>
          </div>

        <% @phase in ["musuhi", :musuhi] -> %>
          <div class="space-y-3">
            <p class="text-sm text-[var(--color-landing-pale)]">
              結びフェーズ: プロジェクトの進捗を確認します。
            </p>
            <button
              phx-click="advance_musuhi_phase"
              class="w-full py-3 bg-kohaku text-white rounded-lg font-bold active:scale-95 transition-transform"
            >
              結びフェーズを進める
            </button>
          </div>

        <% true -> %>
          <p class="text-sm text-[var(--color-landing-text-secondary)]">
            ゲームの進行をお待ちください...
          </p>
      <% end %>
    </div>

    <!-- Active Projects Summary -->
    <%= if length(@active_projects) > 0 do %>
      <div class="bg-white/5 rounded-xl p-4">
        <h3 class="text-sm font-bold text-[var(--color-landing-gold)] mb-2">進行中のプロジェクト</h3>
        <div class="space-y-2">
          <%= for project <- Enum.take(@active_projects, 3) do %>
            <div class="flex items-center justify-between text-sm">
              <span class="text-[var(--color-landing-pale)] truncate">{project.name}</span>
              <span class="text-[var(--color-landing-text-secondary)]">
                {project.progress}/{project.required_participants}
              </span>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <!-- Recent Action Logs -->
    <%= if length(@action_logs) > 0 do %>
      <div class="bg-white/5 rounded-xl p-4">
        <h3 class="text-sm font-bold text-[var(--color-landing-gold)] mb-2">最近のアクション</h3>
        <div class="space-y-2">
          <%= for log <- Enum.take(@action_logs, 5) do %>
            <div class="flex items-center gap-2 text-xs">
              <span class={if log.is_ai, do: "text-blue-400", else: "text-green-400"}>
                {if log.is_ai, do: "🤖", else: "👤"}
              </span>
              <span class="text-[var(--color-landing-pale)] truncate">
                {log.player_name}: {log.card_name || log.action_type}
              </span>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
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
                type: card.type,
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
    String.to_existing_atom(id)
  end

  defp convert_to_atom(id), do: id

  defp get_player_ready_status(players, user_id) when is_list(players) do
    case Enum.find(players, fn p -> (p[:id] || p["id"]) == user_id end) do
      nil -> false
      player -> player[:is_ready] || player["is_ready"] || false
    end
  end

  defp get_player_ready_status(_players, _user_id), do: false

  # カテゴリに応じた絵文字を返す
  defp card_category_emoji("forest"), do: "🌲"
  defp card_category_emoji("culture"), do: "🎭"
  defp card_category_emoji("social"), do: "🤝"
  defp card_category_emoji("akasha"), do: "✨"
  defp card_category_emoji(_), do: "🃏"

  defp current_player_turn?(game_state, user_id) do
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

  # 場に出ているアクションカードを手札として取得（キャッシュから）
  defp get_hand_cards_from_session(_game_session, turn_state) do
    if turn_state && turn_state.available_cards do
      turn_state.available_cards
      |> Shinkanki.CardCache.action_cards_by_ids()
      |> Enum.map(fn card ->
        %{
          id: card.id,
          name: card.name,
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
          # Effect map for modal preview
          effect: %{
            forest: card.effect_forest || 0,
            culture: card.effect_culture || 0,
            social: card.effect_social || 0,
            currency: card.effect_akasha || 0
          },
          tags: [String.to_existing_atom(card.category)]
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

  # 効果サマリーの表示
  defp render_effect_summary(effect) when is_map(effect) do
    effect
    |> Enum.map(fn
      {:forest, v} when v > 0 -> "🌲+#{v}"
      {:forest, v} when v < 0 -> "🌲#{v}"
      {:culture, v} when v > 0 -> "🎭+#{v}"
      {:culture, v} when v < 0 -> "🎭#{v}"
      {:social, v} when v > 0 -> "🤝+#{v}"
      {:social, v} when v < 0 -> "🤝#{v}"
      {:jaki, v} when v > 0 -> "👹+#{v}"
      {:jaki, v} when v < 0 -> "👹#{v}"
      {:orochi_suppress, true} -> "🐉抑制"
      {:orochi_level_down, true} -> "🐉-1"
      _ -> nil
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(" ")
  end
  defp render_effect_summary(_), do: ""

  # 連携カードタグの絵文字
  defp renkei_tag_emoji(:prayer), do: "🙏"
  defp renkei_tag_emoji(:purification), do: "✨"
  defp renkei_tag_emoji(:ritual), do: "🎐"
  defp renkei_tag_emoji(:festival), do: "🎉"
  defp renkei_tag_emoji(:culture), do: "🎭"
  defp renkei_tag_emoji(:nature), do: "🌿"
  defp renkei_tag_emoji(:community), do: "🤝"
  defp renkei_tag_emoji(:grow), do: "🌱"
  defp renkei_tag_emoji(:protection), do: "🛡️"
  defp renkei_tag_emoji(:kitchen), do: "🍳"
  defp renkei_tag_emoji(:care), do: "💝"
  defp renkei_tag_emoji(:network), do: "🔗"
  defp renkei_tag_emoji(:dialogue), do: "💬"
  defp renkei_tag_emoji(:resistance), do: "✊"
  defp renkei_tag_emoji(_), do: "📿"

  # 磨きカードカテゴリの絵文字
  defp migaki_category_emoji(:kitchen), do: "🍳"
  defp migaki_category_emoji(:forest), do: "🌲"
  defp migaki_category_emoji(:festival), do: "🎉"
  defp migaki_category_emoji(:care), do: "💝"
  defp migaki_category_emoji(:ritual), do: "⛩️"
  defp migaki_category_emoji(_), do: "✨"

  # 減衰量を計算（10%）
  defp calculate_demurrage_amount(currency) when is_integer(currency) and currency > 0 do
    -div(currency, 10)
  end

  defp calculate_demurrage_amount(_), do: 0
end
