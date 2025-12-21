defmodule Shinkanki.Game do
  @moduledoc """
  Represents the core game state and pure logic for Shinkanki.
  """

  alias Shinkanki.{Card, Player}

  @initial_hand_size 3
  @max_talents_per_action 2
  @deck_cycles 3
  @min_players 1
  @max_players 4

  defstruct [
    :room_id,
    turn: 1,
    # Forest (F) - Scale 0-10
    forest: 5,
    # Culture (K) - Scale 0-10
    culture: 5,
    # Social (S) - Scale 0-10
    social: 5,
    # Jaki (邪気) - Scale 0-8, initial 6
    jaki: 6,
    # Currency (P/空環) - Now managed per-player, this is legacy/shared pool
    currency: 10,
    # Life Index (L) = F + K + S, max 30
    life_index: 15,
    # :waiting, :playing, :won, :lost
    status: :waiting,
    # Ending type when game ends: :blessing, :purification, :uncertainty, :lament, :instant_loss
    ending_type: nil,
    # Current game phase: :hitoyo, :kamihakari, :itonami, :kokyu, :musuhi, :toshiokuri
    # 人代 → 神議り → 営み → 呼吸 → 結び → 年送り
    phase: :hitoyo,
    # Current hitoyo cards drawn this turn
    current_hitoyo: [],
    logs: [],
    players: %{},
    # Player order for turn-based actions
    player_order: [],
    # Current player index in action phase
    current_player_index: 0,
    deck: [],
    discard_pile: [],
    hands: %{},
    available_projects: [],
    # Project progress tracking: %{project_id => %{progress: integer, contributors: [player_id]}}
    project_progress: %{},
    # Completed projects (to prevent re-contribution)
    completed_projects: [],
    # Event card system
    event_deck: [],
    event_discard_pile: [],
    current_event: nil,
    # === 八岐大蛇システム ===
    # Orochi level: 1-3 (starts at 1 = 1/3 of max power)
    orochi_level: 1,
    # Orochi awakening counter (increases when jaki hits 8)
    orochi_awakening_count: 0,
    # === 連携システム ===
    # Pending renkei (cooperation) actions: %{card_id => %{initiator: player_id, participants: [player_id], kuukan_pledged: %{player_id => amount}}}
    pending_renkei: %{},
    # Completed renkei this turn (to prevent re-triggering)
    completed_renkei: []
  ]

  @type t :: %__MODULE__{
          room_id: String.t(),
          turn: integer(),
          forest: integer(),
          culture: integer(),
          social: integer(),
          jaki: integer(),
          currency: integer(),
          life_index: integer(),
          status: :waiting | :playing | :won | :lost,
          ending_type: atom() | nil,
          phase: atom(),
          logs: list(),
          players: %{optional(String.t()) => Player.t()},
          player_order: list(String.t()),
          current_player_index: integer(),
          deck: list(atom()),
          discard_pile: list(atom()),
          hands: %{optional(String.t()) => list(atom())},
          available_projects: list(atom()),
          project_progress: map(),
          completed_projects: list(atom()),
          event_deck: list(atom()),
          event_discard_pile: list(atom()),
          current_event: atom() | nil,
          current_hitoyo: list(map()),
          orochi_level: integer(),
          orochi_awakening_count: integer(),
          pending_renkei: map(),
          completed_renkei: list(atom())
        }

  @doc """
  Creates a new game state.
  """
  @spec new(String.t()) :: t()
  def new(room_id) do
    %__MODULE__{
      room_id: room_id,
      deck: build_deck(),
      event_deck: build_event_deck()
    }
  end

  @doc """
  Gets the ending type name in Japanese.
  """
  @spec ending_name(atom() | nil) :: String.t() | nil
  def ending_name(:blessing), do: "🌈 神々の祝福エンディング"
  def ending_name(:purification), do: "🌿 浄化の兆しエンディング"
  def ending_name(:uncertainty), do: "🌙 揺らぎの未来エンディング"
  def ending_name(:lament), do: "🔥 神々の嘆き（文明崩壊）"
  def ending_name(:instant_loss), do: "💀 即時ゲームオーバー"
  def ending_name(nil), do: nil
  def ending_name(_), do: nil

  @doc """
  Gets the ending description.
  """
  @spec ending_description(atom() | nil) :: String.t() | nil
  def ending_description(:blessing), do: "世界は神々の祝福に満ち、豊かな未来が約束されました。"
  def ending_description(:purification), do: "世界は浄化の兆しを見せ、希望の光が差し込み始めました。"
  def ending_description(:uncertainty), do: "世界の未来は揺らぎの中にあり、不確かな道が続きます。"
  def ending_description(:lament), do: "神々は嘆き、文明は崩壊の危機に直面しています。"
  def ending_description(:instant_loss), do: "森、文化、またはコミュニティのいずれかが失われ、世界は終わりを迎えました。"
  def ending_description(nil), do: nil
  def ending_description(_), do: nil

  @doc """
  Adds a player to the game. If talents are not provided, two default talents are assigned.
  """
  @spec join(t(), String.t(), String.t(), String.t(), [atom()] | nil) ::
          {:ok, t()} | {:error, atom()}
  def join(%__MODULE__{} = game, player_id, name, avatar \\ "🎮", talent_ids \\ nil) do
    cond do
      game.status in [:won, :lost] ->
        {:error, :game_over}

      game.status == :playing ->
        {:error, :game_already_started}

      length(game.player_order) >= @max_players ->
        {:error, :max_players_reached}

      Map.has_key?(game.players, player_id) ->
        {:error, :already_joined}

      true ->
        talents = prepare_talents(talent_ids)

        player =
          Player.new(player_id, name, avatar)
          |> Map.put(:talents, talents)

        game_with_player = %{
          game
          | players: Map.put(game.players, player_id, player),
            player_order: game.player_order ++ [player_id]
        }

        {:ok,
         game_with_player
         |> draw_cards(player_id, @initial_hand_size)}
    end
  end

  @doc """
  Advances the game to the next turn.
  Resets phase to :event and automatically progresses through all phases until judgment.
  This maintains backward compatibility with existing code that expects next_turn to complete a full turn.
  """
  @spec next_turn(t()) :: t()
  def next_turn(%__MODULE__{status: :playing} = game) do
    result =
      game
      |> clear_current_event()
      |> advance_turn_counter()
      |> set_phase(:event)
      # Event -> Discussion
      |> execute_phase()
      # Discussion -> Action
      |> then(&next_phase/1)
      # Action -> Demurrage -> Life Update -> Judgment
      |> then(&next_phase/1)

    # Execute judgment phase if we're still playing and in judgment phase
    if result.status == :playing and result.phase == :judgment do
      execute_phase(result)
    else
      result
    end
  end

  def next_turn(game), do: game

  @doc """
  Advances to the next phase in the turn flow.
  Executes the current phase (which may auto-advance), then if still in same phase, advances to next.
  """
  @spec next_phase(t()) :: t()
  def next_phase(%__MODULE__{status: :playing} = game) do
    # Execute current phase (some phases auto-advance)
    executed_game = execute_phase(game)

    # If phase didn't change, manually advance to next phase
    if executed_game.phase == game.phase and executed_game.status == :playing do
      new_phase = get_next_phase(game.phase)

      executed_game
      |> set_phase(new_phase)
      |> execute_phase()
    else
      # Phase already advanced by execute_phase, or game ended
      executed_game
    end
  end

  def next_phase(game), do: game

  @doc """
  Updates game statistics (Forest, Culture, Social, Currency).
  """
  @spec update_stats(t(), map()) :: t()
  def update_stats(%__MODULE__{status: :playing} = game, changes) do
    game
    |> apply_changes(changes)
    |> check_orochi_awakening()
    |> check_projects_unlock()
    |> update_life_index()
    |> check_win_loss()
  end

  def update_stats(game, _changes), do: game

  @doc """
  Plays a generic card (legacy support).
  """
  @spec play_card(t(), atom()) :: {:ok, t()} | {:error, atom()}
  def play_card(%__MODULE__{status: :playing} = game, card_id) do
    case Card.get_card(card_id) do
      nil ->
        {:error, :card_not_found}

      card ->
        if game.currency >= card.cost do
          new_game =
            game
            |> pay_cost(card.cost)
            |> apply_changes(card.effect)
            |> update_life_index()
            |> check_win_loss()
            |> add_log("Played card: #{card.name}")

          {:ok, new_game}
        else
          {:error, :not_enough_currency}
        end
    end
  end

  def play_card(_game, _card_id), do: {:error, :game_over}

  @doc """
  Contributes a talent card to a project to advance its progress.
  Returns {:ok, new_game} or {:error, reason}.
  """
  def contribute_talent_to_project(
        %__MODULE__{status: :playing} = game,
        player_id,
        project_id,
        talent_id
      ) do
    with {:player, %Player{} = player} <- {:player, Map.get(game.players, player_id)},
         {:project, %Card{} = project} <- {:project, Card.get_project(project_id)},
         {:unlocked, true} <- {:unlocked, project_id in game.available_projects},
         {:talent, true} <- {:talent, Enum.member?(player.talents, talent_id)},
         {:not_used, true} <- {:not_used, not Enum.member?(player.used_talents, talent_id)},
         {:not_completed, true} <- {:not_completed, not project_completed?(game, project_id)} do
      new_progress = get_project_progress(game, project_id) + 1

      progress_entry = %{
        progress: new_progress,
        contributors: get_project_contributors(game, project_id) ++ [player_id]
      }

      cond do
        new_progress < project.required_progress ->
          updated_progress = Map.put(game.project_progress, project_id, progress_entry)

          new_game =
            %{game | project_progress: updated_progress}
            |> mark_player_used_talents(player_id, [talent_id])
            |> add_log(
              "#{player.name} contributed talent to #{project.name} (#{new_progress}/#{project.required_progress})"
            )

          {:ok, new_game}

        game.currency < project.cost ->
          {:error, :not_enough_currency}

        true ->
          updated_progress = Map.put(game.project_progress, project_id, progress_entry)

          new_game =
            %{game | project_progress: updated_progress}
            |> mark_player_used_talents(player_id, [talent_id])
            |> add_log(
              "#{player.name} contributed talent to #{project.name} (#{new_progress}/#{project.required_progress})"
            )

          complete_project(new_game, project_id, project)
      end
    else
      {:player, nil} -> {:error, :player_not_found}
      {:project, nil} -> {:error, :project_not_found}
      {:unlocked, false} -> {:error, :project_not_unlocked}
      {:talent, false} -> {:error, :talent_not_owned}
      {:not_used, false} -> {:error, :talent_already_used}
      {:not_completed, false} -> {:error, :project_already_completed}
      _ -> {:error, :invalid_request}
    end
  end

  def contribute_talent_to_project(_game, _player_id, _project_id, _talent_id),
    do: {:error, :game_over}

  @doc """
  Marks a player as ready in the discussion phase.
  Returns {:ok, new_game} or {:error, reason}.
  """
  def mark_discussion_ready(%__MODULE__{status: :playing, phase: :discussion} = game, player_id) do
    case Map.get(game.players, player_id) do
      nil ->
        {:error, :player_not_found}

      player ->
        if player.is_ready do
          {:error, :already_ready}
        else
          new_game =
            game
            |> mark_player_ready(player_id)
            |> add_log("#{player.name} is ready for action phase")

          # Check if all players are ready and advance phase
          final_game =
            if all_players_discussion_ready?(new_game) do
              new_game
              |> add_log("All players ready - advancing to action phase")
              |> prepare_action_phase()
            else
              new_game
            end

          {:ok, final_game}
        end
    end
  end

  def mark_discussion_ready(%__MODULE__{phase: phase}, _player_id) when phase != :discussion do
    {:error, :not_discussion_phase}
  end

  def mark_discussion_ready(_game, _player_id), do: {:error, :game_over}

  @doc """
  Starts the game if minimum player requirements are met.
  Returns {:ok, new_game} or {:error, reason}.
  """
  @spec start_game(t()) :: {:ok, t()} | {:error, atom()}
  def start_game(%__MODULE__{status: :waiting} = game) do
    player_count = length(game.player_order)

    cond do
      player_count < @min_players ->
        {:error, :not_enough_players}

      player_count > @max_players ->
        {:error, :too_many_players}

      true ->
        new_game =
          game
          |> Map.put(:status, :playing)
          |> reset_player_state()
          |> add_log("Game started with #{player_count} player(s)")
          # Trigger the first phase (Event)
          |> execute_phase()

        {:ok, new_game}
    end
  end

  def start_game(%__MODULE__{status: :playing}), do: {:error, :game_already_started}
  def start_game(_game), do: {:error, :game_over}

  @doc """
  AIプレイヤーで4人に補完してゲームを開始
  Returns {:ok, new_game} or {:error, reason}.
  """
  @spec start_game_with_ai(t()) :: {:ok, t()} | {:error, atom()}
  def start_game_with_ai(%__MODULE__{status: :waiting} = game) do
    human_count = length(game.player_order)

    if human_count < 1 do
      {:error, :not_enough_players}
    else
      # 足りない分のAIプレイヤーを追加
      ai_count = @max_players - human_count
      game_with_ai = add_ai_players(game, ai_count)

      # ゲーム開始
      new_game =
        game_with_ai
        |> Map.put(:status, :playing)
        |> reset_player_state()
        |> add_log("Game started with #{human_count} human(s) and #{ai_count} AI player(s)")
        # Trigger the first phase (Event)
        |> execute_phase()

      {:ok, new_game}
    end
  end

  def start_game_with_ai(%__MODULE__{status: :playing}), do: {:error, :game_already_started}
  def start_game_with_ai(_game), do: {:error, :game_over}

  defp add_ai_players(game, 0), do: game

  defp add_ai_players(game, count) do
    ai_names = ["森の精霊", "文化の守人", "絆の使者", "空環の賢者"]
    roles = [:forest_guardian, :heritage_weaver, :community_keeper, :akasha_architect]

    # 既に使われている役割を除外
    used_roles =
      Enum.map(game.player_order, fn player_id ->
        Map.get(game.players, player_id, %{}) |> Map.get(:role)
      end)

    available_roles = Enum.reject(roles, &(&1 in used_roles))

    Enum.reduce(1..count, game, fn idx, acc_game ->
      player_order_index = length(acc_game.player_order)
      ai_id = "ai_player_#{idx}"
      ai_name = Enum.at(ai_names, player_order_index, "AI神#{idx}")
      role = Enum.at(available_roles, idx - 1, Enum.at(roles, player_order_index))

      player =
        Player.new(ai_id, ai_name)
        |> Map.put(:is_ai, true)
        |> Map.put(:role, role)

      acc_game
      |> Map.update!(:players, &Map.put(&1, ai_id, player))
      |> Map.update!(:player_order, &(&1 ++ [ai_id]))
      |> draw_cards(ai_id, @initial_hand_size)
    end)
  end

  @doc """
  Toggles a player's ready status in the waiting room (before game starts).
  Returns {:ok, new_game} or {:error, reason}.
  """
  def toggle_waiting_ready(%__MODULE__{status: :waiting} = game, player_id) do
    case Map.get(game.players, player_id) do
      nil ->
        {:error, :player_not_found}

      player ->
        new_ready = !player.is_ready
        updated_player = Map.put(player, :is_ready, new_ready)
        new_players = Map.put(game.players, player_id, updated_player)

        new_game =
          game
          |> Map.put(:players, new_players)
          |> add_log("#{player.name} is #{if new_ready, do: "ready", else: "not ready"}")

        {:ok, new_game}
    end
  end

  def toggle_waiting_ready(%__MODULE__{status: status}, _player_id) when status != :waiting do
    {:error, :game_already_started}
  end

  def toggle_waiting_ready(_game, _player_id), do: {:error, :invalid_game}

  @doc """
  Checks if all players in the waiting room are ready.
  """
  @spec all_players_ready?(t()) :: boolean()
  def all_players_ready?(%__MODULE__{status: :waiting, players: players, player_order: order})
      when map_size(players) > 0 do
    Enum.all?(order, fn player_id ->
      case Map.get(players, player_id) do
        nil -> false
        player -> player.is_ready == true
      end
    end)
  end

  def all_players_ready?(_game), do: false

  @doc """
  Checks if the game can be started (meets minimum player requirements).
  """
  @spec can_start?(t()) :: boolean()
  def can_start?(%__MODULE__{status: :waiting} = game) do
    player_count = length(game.player_order)
    player_count >= @min_players and player_count <= @max_players
  end

  def can_start?(_game), do: false

  @doc """
  Plays an action or project card with optional talent boosters.
  Note: For projects, this executes them immediately (legacy behavior).
  For new projects, use contribute_talent_to_project instead.
  """
  @spec play_action(t(), String.t(), atom(), [atom()]) :: {:ok, t()} | {:error, atom()}
  def play_action(%__MODULE__{} = game, player_id, action_id, talent_ids \\ []) do
    with {:status, :playing} <- {:status, game.status},
         {:player, %Player{} = player} <- {:player, Map.get(game.players, player_id)},
         {:turn, true} <- {:turn, can_player_act?(game, player_id)},
         {:action, %Card{} = card} <- get_action_or_project(game, action_id),
         {:hand, {:ok, game_without_card}} <- handle_card_consumption(game, player_id, card),
         :ok <- validate_talents(player, talent_ids),
         true <- length(talent_ids) <= @max_talents_per_action,
         {:currency, true} <- {:currency, game_without_card.currency >= card.cost} do
      bonus = calculate_bonus(card, talent_ids)

      effect =
        Map.new(card.effect, fn {key, val} ->
          {key, val + bonus}
        end)

      new_game =
        game_without_card
        |> pay_cost(card.cost)
        |> apply_changes(effect)
        |> update_life_index()
        |> check_win_loss()
        |> add_log("#{player.name} played #{card.name} (+#{bonus})")
        |> mark_player_used_talents(player_id, talent_ids)
        |> mark_player_ready(player_id)
        # Only replenish if it was a regular action card
        |> maybe_replenish_hand(player_id, card.type)
        |> check_projects_unlock()
        |> advance_to_next_player()
        |> maybe_advance_turn()

      {:ok, new_game}
    else
      {:status, _} -> {:error, :game_over}
      {:player, nil} -> {:error, :player_not_found}
      {:turn, false} -> {:error, :not_your_turn}
      {:action, {:error, reason}} -> {:error, reason}
      {:hand, {:error, reason}} -> {:error, reason}
      {:currency, false} -> {:error, :not_enough_currency}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_request}
    end
  end

  defp can_player_act?(%__MODULE__{phase: phase} = game, player_id)
       when phase in [:action, :itonami] do
    # In action/itonami phase, check if it's the player's turn
    current_player = get_current_player(game)
    current_player == player_id
  end

  defp can_player_act?(%__MODULE__{phase: phase}, _player_id)
       when phase not in [:action, :itonami] do
    # Outside action/itonami phase, all players can act (for backward compatibility)
    true
  end

  defp can_player_act?(_game, _player_id), do: false

  defp get_action_or_project(game, card_id) do
    case Card.get_action(card_id) do
      nil ->
        case Card.get_project(card_id) do
          nil ->
            {:action, {:error, :action_not_found}}

          project ->
            if project.id in game.available_projects do
              {:action, project}
            else
              {:action, {:error, :project_not_unlocked}}
            end
        end

      action ->
        {:action, action}
    end
  end

  defp handle_card_consumption(game, player_id, %Card{type: :action} = card) do
    case remove_card_from_hand(game, player_id, card.id) do
      {:ok, new_game} -> {:hand, {:ok, add_to_discard(new_game, card.id)}}
      error -> {:hand, error}
    end
  end

  # Projects are not in hand, so no consumption/discard logic needed for them
  defp handle_card_consumption(game, _player_id, %Card{type: :project}), do: {:hand, {:ok, game}}

  defp maybe_replenish_hand(game, player_id, :action), do: draw_cards(game, player_id, 1)
  defp maybe_replenish_hand(game, _player_id, _type), do: game

  defp check_projects_unlock(game) do
    unlocked =
      Card.list_projects()
      |> Enum.filter(fn project ->
        Enum.all?(project.unlock_condition, fn {key, val} ->
          Map.get(game, key, 0) >= val
        end)
      end)
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    %{game | available_projects: Enum.uniq(game.available_projects ++ unlocked)}
  end

  defp apply_demurrage(game) do
    new_currency = floor(game.currency * 0.9)
    %{game | currency: new_currency}
  end

  defp advance_turn_counter(game) do
    %{game | turn: game.turn + 1}
  end

  defp pay_cost(game, cost) do
    %{game | currency: game.currency - cost}
  end

  defp apply_changes(game, changes) do
    Enum.reduce(changes, game, fn {key, val}, acc ->
      case key do
        :forest -> %{acc | forest: clamp(acc.forest + val, 0, 10)}
        :culture -> %{acc | culture: clamp(acc.culture + val, 0, 10)}
        :social -> %{acc | social: clamp(acc.social + val, 0, 10)}
        :jaki -> %{acc | jaki: clamp(acc.jaki + val, 0, 8)}
        :currency -> %{acc | currency: max(acc.currency + val, 0)}
        _ -> acc
      end
    end)
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  defp update_life_index(game) do
    %{game | life_index: game.forest + game.culture + game.social}
  end

  defp check_win_loss(game) do
    cond do
      # 即時ゲームオーバー: F=0 or K=0 or S=0
      game.forest <= 0 or game.culture <= 0 or game.social <= 0 ->
        %{game | status: :lost, ending_type: :instant_loss}

      # ターン20を超えた場合、Life Indexに基づいてエンディング判定
      game.turn > 20 ->
        determine_ending(game)

      true ->
        game
    end
  end

  defp determine_ending(game) do
    cond do
      # 🌈 神々の祝福エンディング (L >= 24, max 30)
      game.life_index >= 24 ->
        %{game | status: :won, ending_type: :blessing}

      # 🌿 浄化の兆しエンディング (18 <= L < 24)
      game.life_index >= 18 ->
        %{game | status: :won, ending_type: :purification}

      # 🌙 揺らぎの未来エンディング (12 <= L < 18)
      game.life_index >= 12 ->
        %{game | status: :lost, ending_type: :uncertainty}

      # 🔥 神々の嘆き（文明崩壊）(L < 12)
      true ->
        %{game | status: :lost, ending_type: :lament}
    end
  end

  defp add_log(game, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    log_entry = "[#{timestamp}] Turn #{game.turn}: #{message}"
    %{game | logs: [log_entry | game.logs]}
  end

  defp mark_player_ready(game, player_id) do
    case Map.get(game.players, player_id) do
      nil ->
        game

      player ->
        updated_player = %{player | is_ready: true}
        %{game | players: Map.put(game.players, player_id, updated_player)}
    end
  end

  @doc """
  Marks a player as ready for action phase (public API for AI skip).
  Also advances to next player and potentially advances the turn.
  """
  @spec mark_player_ready_for_action(t(), String.t()) :: {:ok, t()}
  def mark_player_ready_for_action(%__MODULE__{} = game, player_id) do
    new_game =
      game
      |> mark_player_ready(player_id)
      |> advance_to_next_player()
      |> maybe_advance_turn()

    {:ok, new_game}
  end

  defp mark_player_used_talents(game, player_id, talent_ids) do
    case Map.get(game.players, player_id) do
      nil ->
        game

      player ->
        updated_player = %{player | used_talents: player.used_talents ++ talent_ids}
        %{game | players: Map.put(game.players, player_id, updated_player)}
    end
  end

  defp maybe_advance_turn(%__MODULE__{status: :playing, phase: phase} = game)
       when phase in [:action, :itonami] do
    players = Map.values(game.players)

    cond do
      players == [] ->
        game

      Enum.all?(players, fn
        %Player{is_ready: ready} -> ready
        _ -> false
      end) ->
        # All players ready - advance to next phase (kokyu for itonami, demurrage for action)
        next_phase(game)

      true ->
        game
    end
  end

  defp maybe_advance_turn(game), do: game

  defp advance_to_next_player(%__MODULE__{phase: phase, player_order: []} = game)
       when phase in [:action, :itonami],
       do: game

  defp advance_to_next_player(
         %__MODULE__{phase: phase, player_order: order, current_player_index: index} = game
       )
       when phase in [:action, :itonami] do
    next_index = rem(index + 1, length(order))
    %{game | current_player_index: next_index}
  end

  defp advance_to_next_player(game), do: game

  @doc """
  Gets the current player ID in action/itonami phase.
  """
  @spec get_current_player(t()) :: String.t() | nil
  def get_current_player(%__MODULE__{
        phase: phase,
        player_order: order,
        current_player_index: index
      })
      when phase in [:action, :itonami] do
    if order != [] and index < length(order) do
      Enum.at(order, index)
    else
      nil
    end
  end

  def get_current_player(_game), do: nil

  defp get_current_player_name(game) do
    case get_current_player(game) do
      nil ->
        "Unknown"

      player_id ->
        case Map.get(game.players, player_id) do
          nil -> "Unknown"
          player -> player.name
        end
    end
  end

  defp all_players_discussion_ready?(game) do
    players = Map.values(game.players)

    cond do
      players == [] ->
        false

      Enum.all?(players, fn
        %Player{is_ready: ready} -> ready
        _ -> false
      end) ->
        true

      true ->
        false
    end
  end

  defp reset_player_state(game) do
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        {id, %{player | is_ready: false, used_talents: []}}
      end)

    %{game | players: players, current_player_index: 0}
  end

  defp prepare_talents(nil) do
    Card.list_talents()
    |> Enum.map(& &1.id)
    |> Enum.take(@max_talents_per_action)
  end

  defp prepare_talents(ids) when is_list(ids) do
    ids
    |> Enum.map(&Card.get_talent/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(& &1.id)
    |> Enum.take(@max_talents_per_action)
  end

  defp validate_talents(%Player{} = player, talent_ids) do
    cond do
      # Check if player owns the talents
      not Enum.all?(talent_ids, &Enum.member?(player.talents, &1)) ->
        {:error, :invalid_talent}

      # Check if talents were already used this turn
      Enum.any?(talent_ids, &Enum.member?(player.used_talents, &1)) ->
        {:error, :talent_already_used}

      # Check for duplicates in the current request (must be distinct talents)
      length(Enum.uniq(talent_ids)) != length(talent_ids) ->
        {:error, :duplicate_talent_usage}

      true ->
        :ok
    end
  end

  defp calculate_bonus(%Card{} = action, talent_ids) do
    talent_ids
    |> Enum.map(&Card.get_talent/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(0, fn talent, acc ->
      if Enum.any?(talent.compatible_tags, &Enum.member?(action.tags, &1)) do
        acc + 1
      else
        acc
      end
    end)
    |> min(@max_talents_per_action)
  end

  defp build_deck do
    Card.list_actions()
    |> Enum.map(& &1.id)
    |> List.duplicate(@deck_cycles)
    |> List.flatten()
    |> Enum.shuffle()
  end

  defp draw_cards(game, player_id, count) do
    {drawn, updated_game} = take_from_deck(game, count, [])

    new_hands =
      Map.update(updated_game.hands, player_id, drawn, fn hand ->
        hand ++ drawn
      end)

    %{updated_game | hands: new_hands}
  end

  defp take_from_deck(game, 0, acc), do: {Enum.reverse(acc), game}

  defp take_from_deck(%{deck: []} = game, count, acc) do
    case game.discard_pile do
      [] ->
        # No cards available - return what we have
        {Enum.reverse(acc), game}

      discard ->
        # Deck is empty - reshuffle discard pile to create new deck
        reshuffled = Enum.shuffle(discard)

        game_with_log =
          add_log(game, "Deck reshuffled from discard pile (#{length(discard)} cards)")

        take_from_deck(%{game_with_log | deck: reshuffled, discard_pile: []}, count, acc)
    end
  end

  defp take_from_deck(%{deck: [card | rest]} = game, count, acc) do
    take_from_deck(%{game | deck: rest}, count - 1, [card | acc])
  end

  defp remove_card_from_hand(game, player_id, card_id) do
    hand = Map.get(game.hands, player_id, [])

    if card_id in hand do
      new_hand = List.delete(hand, card_id)
      new_hands = Map.put(game.hands, player_id, new_hand)
      {:ok, %{game | hands: new_hands}}
    else
      {:error, :card_not_in_hand}
    end
  end

  defp add_to_discard(game, card_id) do
    %{game | discard_pile: [card_id | game.discard_pile]}
  end

  # === Event Card System ===

  defp build_event_deck do
    Card.list_events()
    |> Enum.map(& &1.id)
    |> Enum.shuffle()
  end

  defp draw_and_apply_event(game) do
    case take_from_event_deck(game, 1, []) do
      {[event_id], updated_game} ->
        event = Card.get_event(event_id)

        if event do
          updated_game
          |> apply_event_effect(event)
          |> set_current_event(event_id)
          |> add_log("Event: #{event.name}")
        else
          updated_game
        end

      {[], updated_game} ->
        # No event cards available (shouldn't happen, but handle gracefully)
        updated_game
    end
  end

  defp apply_event_effect(game, %Card{} = event) do
    apply_changes(game, event.effect)
  end

  defp set_current_event(game, event_id) do
    %{game | current_event: event_id}
  end

  defp take_from_event_deck(game, 0, acc), do: {Enum.reverse(acc), game}

  defp take_from_event_deck(%{event_deck: []} = game, count, acc) do
    case game.event_discard_pile do
      [] ->
        # No more event cards - reshuffle if we have any, otherwise return what we have
        {Enum.reverse(acc), game}

      discard ->
        # Reshuffle event discard pile
        reshuffled = Enum.shuffle(discard)
        take_from_event_deck(%{game | event_deck: reshuffled, event_discard_pile: []}, count, acc)
    end
  end

  defp take_from_event_deck(%{event_deck: [card | rest]} = game, count, acc) do
    take_from_event_deck(%{game | event_deck: rest}, count - 1, [card | acc])
  end

  # Clear current event at the end of turn (before next event is drawn)
  defp clear_current_event(game) do
    case game.current_event do
      nil ->
        game

      event_id ->
        %{game | current_event: nil, event_discard_pile: [event_id | game.event_discard_pile]}
    end
  end

  # === Phase Management System ===
  # New phase flow: 人代(hitoyo) → 神議り(kamihakari) → 営み(itonami) → 呼吸(kokyu) → 結び(musuhi) → 年送り(toshiokuri)

  defp set_phase(game, phase) do
    %{game | phase: phase}
  end

  # New phase names
  defp get_next_phase(:hitoyo), do: :kamihakari
  defp get_next_phase(:kamihakari), do: :itonami
  defp get_next_phase(:itonami), do: :kokyu
  defp get_next_phase(:kokyu), do: :musuhi
  defp get_next_phase(:musuhi), do: :toshiokuri
  defp get_next_phase(:toshiokuri), do: :hitoyo
  # Legacy phase names for backward compatibility
  defp get_next_phase(:event), do: :discussion
  defp get_next_phase(:discussion), do: :action
  defp get_next_phase(:action), do: :demurrage
  defp get_next_phase(:demurrage), do: :life_update
  defp get_next_phase(:life_update), do: :judgment
  defp get_next_phase(:judgment), do: :event
  defp get_next_phase(_), do: :hitoyo

  # === 人代フェーズ (Hitoyo Phase) ===
  # Draw hitoyo cards based on jaki level and orochi level
  defp execute_phase(%__MODULE__{status: :playing, phase: :hitoyo} = game) do
    # 八岐大蛇システム: レベルに応じて人代カードの枚数と効果が変化
    hitoyo_count = get_hitoyo_count(game.jaki, game.orochi_level)
    hitoyo_cards = Card.draw_hitoyo_cards_count(hitoyo_count)

    # 八岐大蛇レベルに応じて効果を強化
    effect_multiplier = get_orochi_effect_multiplier(game.orochi_level)

    game
    |> Map.put(:current_hitoyo, hitoyo_cards)
    |> apply_hitoyo_effects_with_orochi(hitoyo_cards, effect_multiplier)
    |> add_log("人代フェーズ: #{length(hitoyo_cards)}枚（八岐大蛇Lv#{game.orochi_level}、邪気#{game.jaki}）")
    |> set_phase(:kamihakari)
  end

  # === 神議りフェーズ (Kamihakari Phase) ===
  # Discussion phase - players discuss strategy
  defp execute_phase(%__MODULE__{status: :playing, phase: :kamihakari} = game) do
    if all_players_discussion_ready?(game) do
      game
      |> add_log("神議りフェーズ完了 - 営みフェーズへ")
      |> prepare_itonami_phase()
    else
      game
    end
  end

  # === 営みフェーズ (Itonami Phase) ===
  # Action phase - players play cards
  defp execute_phase(%__MODULE__{status: :playing, phase: :itonami} = game), do: game

  # === 呼吸フェーズ (Kokyu Phase) ===
  # Kanryu phase - players with kuukan >= 5 must return at least 1
  defp execute_phase(%__MODULE__{status: :playing, phase: :kokyu} = game) do
    game
    |> process_kokyu_phase()
    |> set_phase(:musuhi)
  end

  # === 結びフェーズ (Musuhi Phase) ===
  # Players give musuhi chips to each other
  defp execute_phase(%__MODULE__{status: :playing, phase: :musuhi} = game) do
    game
    |> distribute_musuhi_chips()
    |> set_phase(:toshiokuri)
  end

  # === 年送りフェーズ (Toshiokuri Phase) ===
  # End of turn - check win/loss
  defp execute_phase(%__MODULE__{status: :playing, phase: :toshiokuri} = game) do
    updated_game =
      game
      |> reset_player_state_for_new_turn()
      |> check_projects_unlock()
      |> update_life_index()
      |> check_win_loss()

    if updated_game.status == :playing do
      set_phase(updated_game, :hitoyo)
    else
      set_phase(updated_game, :toshiokuri)
    end
  end

  # Legacy phase handlers for backward compatibility
  defp execute_phase(%__MODULE__{status: :playing, phase: :event} = game) do
    game
    |> draw_and_apply_event()
    |> set_phase(:discussion)
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :discussion} = game) do
    if all_players_discussion_ready?(game) do
      game
      |> add_log("All players ready - advancing to action phase")
      |> prepare_action_phase()
    else
      game
    end
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :action} = game), do: game

  defp execute_phase(%__MODULE__{status: :playing, phase: :demurrage} = game) do
    game
    |> apply_demurrage()
    |> set_phase(:life_update)
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :life_update} = game) do
    game
    |> reset_player_state()
    |> check_projects_unlock()
    |> update_life_index()
    |> set_phase(:judgment)
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :judgment} = game) do
    updated_game = check_win_loss(game)

    if updated_game.status == :playing do
      set_phase(updated_game, :event)
    else
      set_phase(updated_game, :judgment)
    end
  end

  defp execute_phase(game), do: game

  # === Helper functions for new phases ===

  # 八岐大蛇レベルと邪気に応じた人代カード枚数
  # レベル1: 2枚固定（初期状態）
  # レベル2: 2-3枚（邪気に応じて）
  # レベル3: 3枚固定 + 特殊効果
  defp get_hitoyo_count(jaki, orochi_level) do
    base_count =
      case orochi_level do
        1 -> 2
        2 -> if jaki >= 5, do: 3, else: 2
        3 -> 3
        _ -> 2
      end

    # 邪気がMAX(8)の場合、追加で1枚
    if jaki >= 8, do: min(base_count + 1, 4), else: base_count
  end

  # 八岐大蛇レベルに応じた効果倍率
  defp get_orochi_effect_multiplier(orochi_level) do
    case orochi_level do
      1 -> 1.0
      2 -> 1.25
      3 -> 1.5
      _ -> 1.0
    end
  end

  # 八岐大蛇の効果を適用した人代効果
  defp apply_hitoyo_effects_with_orochi(game, hitoyo_cards, multiplier) do
    Enum.reduce(hitoyo_cards, game, fn card, acc ->
      if card.timing == :instant do
        # 効果を八岐大蛇レベルで強化（負の効果をより強く）
        enhanced_effect =
          Map.new(card.effect, fn {key, val} ->
            if val < 0 do
              # 負の効果は倍率を適用（切り捨て）
              {key, trunc(val * multiplier)}
            else
              {key, val}
            end
          end)

        apply_changes(acc, enhanced_effect)
        |> check_orochi_awakening()
        |> add_log("人代「#{card.name}」の効果を適用（×#{multiplier}）")
      else
        # Delayed effects are tracked but not applied immediately
        acc
        |> add_log("人代「#{card.name}」（遅延効果）")
      end
    end)
  end

  # 八岐大蛇の覚醒チェック（邪気が8に達したとき）
  defp check_orochi_awakening(%__MODULE__{jaki: 8, orochi_level: level} = game) when level < 3 do
    new_level = level + 1

    game
    |> Map.put(:orochi_level, new_level)
    |> Map.put(:orochi_awakening_count, game.orochi_awakening_count + 1)
    |> add_log("⚠️ 八岐大蛇が覚醒！レベル#{new_level}に上昇！")
  end

  defp check_orochi_awakening(game), do: game

  defp process_kokyu_phase(game) do
    # For now, auto-process kokyu for players with kuukan >= 5
    # In the full implementation, players would choose how much to return
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        if Player.must_kanryu?(player) do
          # Auto-return 1 kuukan and boost a random stat
          updated_player = %{player | kuukan: player.kuukan - 1}
          {id, updated_player}
        else
          {id, player}
        end
      end)

    %{game | players: players}
  end

  defp distribute_musuhi_chips(game) do
    # Give each player 1 musuhi chip to distribute
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        {id, Player.reset_musuhi(player)}
      end)

    %{game | players: players}
  end

  defp reset_player_state_for_new_turn(game) do
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        {id, %{player | is_ready: false, used_talents: [], musuhi_received: 0}}
      end)

    %{game | players: players, current_player_index: 0, current_hitoyo: []}
  end

  defp prepare_itonami_phase(%__MODULE__{} = game) do
    game
    |> reset_action_phase_readiness()
    |> Map.put(:current_player_index, 0)
    |> set_phase(:itonami)
    |> log_itonami_phase_start()
  end

  defp log_itonami_phase_start(%__MODULE__{player_order: []} = game), do: game

  defp log_itonami_phase_start(%__MODULE__{} = game) do
    add_log(game, "営みフェーズ開始 - #{get_current_player_name(game)}の番")
  end

  defp prepare_action_phase(%__MODULE__{} = game) do
    game
    |> reset_action_phase_readiness()
    |> Map.put(:current_player_index, 0)
    |> set_phase(:action)
    |> log_action_phase_start()
  end

  defp reset_action_phase_readiness(%__MODULE__{} = game) do
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        {id, %{player | is_ready: false}}
      end)

    %{game | players: players}
  end

  defp log_action_phase_start(%__MODULE__{player_order: []} = game), do: game

  defp log_action_phase_start(%__MODULE__{} = game) do
    add_log(game, "Action phase started - #{get_current_player_name(game)}'s turn")
  end

  # === Project Progress Management ===

  defp get_project_progress(game, project_id) do
    case Map.get(game.project_progress, project_id) do
      nil -> 0
      %{progress: progress} -> progress
      _ -> 0
    end
  end

  defp get_project_contributors(game, project_id) do
    case Map.get(game.project_progress, project_id) do
      nil -> []
      %{contributors: contributors} -> contributors
      _ -> []
    end
  end

  defp project_completed?(game, project_id) do
    # Check if project is in completed_projects list
    project_id in game.completed_projects
  end

  defp complete_project(%__MODULE__{currency: currency}, _project_id, %Card{cost: cost})
       when currency < cost do
    {:error, :not_enough_currency}
  end

  defp complete_project(game, project_id, %Card{} = project) do
    new_game =
      game
      |> pay_cost(project.cost)
      |> apply_changes(project.effect)
      |> update_life_index()
      |> check_win_loss()
      |> add_log("Project #{project.name} completed! Effect applied.")
      |> mark_project_completed(project_id)
      |> remove_project_from_progress(project_id)

    {:ok, new_game}
  end

  defp mark_project_completed(game, project_id) do
    %{game | completed_projects: [project_id | game.completed_projects]}
  end

  defp remove_project_from_progress(game, project_id) do
    %{game | project_progress: Map.delete(game.project_progress, project_id)}
  end

  @doc """
  Gets the current phase name in Japanese.
  """
  @spec phase_name(atom()) :: String.t()
  # New phase names
  def phase_name(:hitoyo), do: "人代フェーズ"
  def phase_name(:kamihakari), do: "神議りフェーズ"
  def phase_name(:itonami), do: "営みフェーズ"
  def phase_name(:kokyu), do: "呼吸フェーズ"
  def phase_name(:musuhi), do: "結びフェーズ"
  def phase_name(:toshiokuri), do: "年送りフェーズ"
  # Legacy phase names
  def phase_name(:event), do: "イベントフェーズ"
  def phase_name(:discussion), do: "相談フェーズ"
  def phase_name(:action), do: "アクションフェーズ"
  def phase_name(:demurrage), do: "減衰フェーズ"
  def phase_name(:life_update), do: "生命更新フェーズ"
  def phase_name(:judgment), do: "判定フェーズ"
  def phase_name(_), do: "不明"

  @doc """
  Checks if the game is in a specific phase.
  """
  @spec in_phase?(t(), atom()) :: boolean()
  def in_phase?(%__MODULE__{} = game, phase) do
    game.phase == phase
  end

  # ============================================================
  # === 連携（れんけい）カードシステム ===
  # ============================================================

  @doc """
  連携カードを提案する（開始プレイヤーが呼び出す）
  Returns {:ok, new_game} or {:error, reason}
  """
  @spec initiate_renkei(t(), String.t(), atom()) :: {:ok, t()} | {:error, atom()}
  def initiate_renkei(%__MODULE__{status: :playing} = game, player_id, renkei_card_id) do
    with {:player, %Player{} = player} <- {:player, Map.get(game.players, player_id)},
         {:card, %Card{type: :renkei} = card} <- {:card, Card.get_renkei(renkei_card_id)},
         {:not_pending, true} <-
           {:not_pending, not Map.has_key?(game.pending_renkei, renkei_card_id)},
         {:not_completed, true} <-
           {:not_completed, renkei_card_id not in game.completed_renkei},
         {:can_pay, true} <- {:can_pay, Player.can_pay?(player, card.cost_per_player)} do
      # 提案を登録
      pending_entry = %{
        initiator: player_id,
        participants: [player_id],
        kuukan_pledged: %{player_id => card.cost_per_player},
        card: card,
        created_at: DateTime.utc_now()
      }

      new_game =
        game
        |> Map.update!(:pending_renkei, &Map.put(&1, renkei_card_id, pending_entry))
        |> add_log("#{player.name}が「#{card.name}」の連携を提案！（#{card.required_players}人必要）")

      {:ok, new_game}
    else
      {:player, nil} -> {:error, :player_not_found}
      {:card, nil} -> {:error, :renkei_card_not_found}
      {:not_pending, false} -> {:error, :renkei_already_pending}
      {:not_completed, false} -> {:error, :renkei_already_completed}
      {:can_pay, false} -> {:error, :insufficient_kuukan}
      _ -> {:error, :invalid_request}
    end
  end

  def initiate_renkei(_game, _player_id, _renkei_card_id), do: {:error, :game_not_playing}

  @doc """
  連携カードに参加する
  Returns {:ok, new_game} or {:error, reason}
  """
  @spec join_renkei(t(), String.t(), atom()) :: {:ok, t()} | {:error, atom()}
  def join_renkei(%__MODULE__{status: :playing} = game, player_id, renkei_card_id) do
    with {:player, %Player{} = player} <- {:player, Map.get(game.players, player_id)},
         {:pending, %{} = pending} <- {:pending, Map.get(game.pending_renkei, renkei_card_id)},
         {:not_joined, true} <- {:not_joined, player_id not in pending.participants},
         {:can_pay, true} <- {:can_pay, Player.can_pay?(player, pending.card.cost_per_player)} do
      # 参加を追加
      updated_pending = %{
        pending
        | participants: pending.participants ++ [player_id],
          kuukan_pledged: Map.put(pending.kuukan_pledged, player_id, pending.card.cost_per_player)
      }

      new_game =
        game
        |> Map.update!(:pending_renkei, &Map.put(&1, renkei_card_id, updated_pending))
        |> add_log(
          "#{player.name}が「#{pending.card.name}」の連携に参加！（#{length(updated_pending.participants)}/#{pending.card.required_players}）"
        )

      # 必要人数が集まったら自動発動
      if length(updated_pending.participants) >= pending.card.required_players do
        execute_renkei(new_game, renkei_card_id)
      else
        {:ok, new_game}
      end
    else
      {:player, nil} -> {:error, :player_not_found}
      {:pending, nil} -> {:error, :renkei_not_pending}
      {:not_joined, false} -> {:error, :already_joined}
      {:can_pay, false} -> {:error, :insufficient_kuukan}
      _ -> {:error, :invalid_request}
    end
  end

  def join_renkei(_game, _player_id, _renkei_card_id), do: {:error, :game_not_playing}

  @doc """
  連携カードを発動する（必要人数が集まったとき）
  """
  def execute_renkei(%__MODULE__{} = game, renkei_card_id) do
    case Map.get(game.pending_renkei, renkei_card_id) do
      nil ->
        {:error, :renkei_not_pending}

      pending ->
        card = pending.card
        participants = pending.participants
        player_count = length(game.player_order)

        # 全員参加かどうかをチェック
        is_full_party = length(participants) >= player_count

        # 基本効果を適用
        game_with_effect = apply_changes(game, card.effect)

        # 全員参加ボーナスを適用
        game_with_bonus =
          if is_full_party do
            apply_renkei_full_party_bonus(game_with_effect, card.full_party_bonus)
          else
            game_with_effect
          end

        # 参加者から空環を差し引く
        game_with_costs =
          Enum.reduce(participants, game_with_bonus, fn pid, acc ->
            case Map.get(acc.players, pid) do
              nil ->
                acc

              player ->
                cost = Map.get(pending.kuukan_pledged, pid, card.cost_per_player)
                {:ok, updated_player} = Player.pay_kuukan(player, cost)
                %{acc | players: Map.put(acc.players, pid, updated_player)}
            end
          end)

        # 連携を完了としてマーク
        bonus_msg = if is_full_party, do: "・全員ボーナス！", else: ""

        new_game =
          game_with_costs
          |> Map.update!(:pending_renkei, &Map.delete(&1, renkei_card_id))
          |> Map.update!(:completed_renkei, &[renkei_card_id | &1])
          |> update_life_index()
          |> check_win_loss()
          |> add_log("🎉 連携「#{card.name}」発動！（#{length(participants)}人参加#{bonus_msg}）")

        {:ok, new_game}
    end
  end

  # 全員参加ボーナスを適用
  defp apply_renkei_full_party_bonus(game, bonus) do
    Enum.reduce(bonus, game, fn {key, val}, acc ->
      case key do
        :orochi_suppress ->
          # 八岐大蛇の覚醒を1ターン抑制（実装は簡略化）
          acc

        :orochi_level_down when val == true ->
          # 八岐大蛇レベルを1下げる（最低1）
          new_level = max(acc.orochi_level - 1, 1)

          acc
          |> Map.put(:orochi_level, new_level)
          |> add_log("⚔️ 八岐大蛇の力が弱まった！（レベル#{new_level}）")

        :forest ->
          %{acc | forest: clamp(acc.forest + val, 0, 10)}

        :culture ->
          %{acc | culture: clamp(acc.culture + val, 0, 10)}

        :social ->
          %{acc | social: clamp(acc.social + val, 0, 10)}

        :jaki ->
          %{acc | jaki: clamp(acc.jaki + val, 0, 8)}

        _ ->
          acc
      end
    end)
  end

  @doc """
  連携の提案をキャンセルする（提案者のみ可能）
  """
  def cancel_renkei(%__MODULE__{} = game, player_id, renkei_card_id) do
    case Map.get(game.pending_renkei, renkei_card_id) do
      nil ->
        {:error, :renkei_not_pending}

      %{initiator: ^player_id} = pending ->
        new_game =
          game
          |> Map.update!(:pending_renkei, &Map.delete(&1, renkei_card_id))
          |> add_log("「#{pending.card.name}」の連携がキャンセルされました")

        {:ok, new_game}

      _ ->
        {:error, :not_initiator}
    end
  end

  @doc """
  利用可能な連携カードのリストを取得
  """
  @spec available_renkei_cards(t()) :: [Card.t()]
  def available_renkei_cards(%__MODULE__{} = game) do
    Card.list_renkei()
    |> Enum.reject(fn card ->
      card.id in game.completed_renkei or Map.has_key?(game.pending_renkei, card.id)
    end)
  end

  @doc """
  現在保留中の連携を取得
  """
  def pending_renkei_list(%__MODULE__{} = game) do
    Map.values(game.pending_renkei)
  end

  @doc """
  八岐大蛇レベルを取得
  """
  @spec orochi_level(t()) :: integer()
  def orochi_level(%__MODULE__{orochi_level: level}), do: level

  @doc """
  八岐大蛇の状態を取得（UI表示用）
  """
  @spec orochi_status(t()) :: map()
  def orochi_status(%__MODULE__{orochi_level: level, jaki: jaki}) do
    status =
      case level do
        1 -> "目覚め始め"
        2 -> "覚醒"
        3 -> "完全覚醒"
        _ -> "封印中"
      end

    next_awakening = if jaki >= 6, do: "⚠️ 覚醒間近", else: ""

    %{
      level: level,
      max_level: 3,
      status: status,
      jaki: jaki,
      warning: next_awakening
    }
  end
end
