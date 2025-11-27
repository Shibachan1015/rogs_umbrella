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
    # Forest (F)
    forest: 50,
    # Culture (K)
    culture: 50,
    # Social (S)
    social: 50,
    # Currency (P)
    currency: 100,
    # Life Index (L) = F + K + S
    life_index: 150,
    # :waiting, :playing, :won, :lost
    status: :waiting,
    # Ending type when game ends: :blessing, :purification, :uncertainty, :lament, :instant_loss
    ending_type: nil,
    # Current game phase: :event, :discussion, :action, :demurrage, :life_update, :judgment
    phase: :event,
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
    current_event: nil
  ]

  @type t :: %__MODULE__{
          room_id: String.t(),
          turn: integer(),
          forest: integer(),
          culture: integer(),
          social: integer(),
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
          current_event: atom() | nil
        }

  @doc """
  Creates a new game state.
  """
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
  def join(%__MODULE__{} = game, player_id, name, talent_ids \\ nil) do
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
          Player.new(player_id, name)
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
  def update_stats(%__MODULE__{status: :playing} = game, changes) do
    game
    |> apply_changes(changes)
    |> check_projects_unlock()
    |> update_life_index()
    |> check_win_loss()
  end

  def update_stats(game, _changes), do: game

  @doc """
  Plays a generic card (legacy support).
  """
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
         {:not_completed, true} <- {:not_completed, not is_project_completed?(game, project_id)} do
      # Add progress to project
      new_progress = get_project_progress(game, project_id) + 1

      updated_progress =
        Map.put(game.project_progress, project_id, %{
          progress: new_progress,
          contributors: get_project_contributors(game, project_id) ++ [player_id]
        })

      new_game =
        %{game | project_progress: updated_progress}
        |> mark_player_used_talents(player_id, [talent_id])
        |> add_log(
          "#{player.name} contributed talent to #{project.name} (#{new_progress}/#{project.required_progress})"
        )

      # Check if project is completed
      if new_progress >= project.required_progress do
        complete_project(new_game, project_id, project)
      else
        {:ok, new_game}
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
              |> set_phase(:action)
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
          |> add_log("Game started with #{player_count} player(s)")
          |> execute_phase() # Trigger the first phase (Event)

        {:ok, new_game}
    end
  end

  def start_game(%__MODULE__{status: :playing}), do: {:error, :game_already_started}
  def start_game(_game), do: {:error, :game_over}

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

  defp can_player_act?(%__MODULE__{phase: :action} = game, player_id) do
    # In action phase, check if it's the player's turn
    current_player = get_current_player(game)
    current_player == player_id
  end

  defp can_player_act?(%__MODULE__{phase: phase}, _player_id) when phase != :action do
    # Outside action phase, all players can act (for backward compatibility)
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
        :forest -> %{acc | forest: acc.forest + val}
        :culture -> %{acc | culture: acc.culture + val}
        :social -> %{acc | social: acc.social + val}
        :currency -> %{acc | currency: acc.currency + val}
        _ -> acc
      end
    end)
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
      # 🌈 神々の祝福エンディング (L >= 40)
      game.life_index >= 40 ->
        %{game | status: :won, ending_type: :blessing}

      # 🌿 浄化の兆しエンディング (30 <= L < 40)
      game.life_index >= 30 ->
        %{game | status: :won, ending_type: :purification}

      # 🌙 揺らぎの未来エンディング (20 <= L < 30)
      game.life_index >= 20 ->
        %{game | status: :lost, ending_type: :uncertainty}

      # 🔥 神々の嘆き（文明崩壊）(L <= 19)
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

  defp mark_player_used_talents(game, player_id, talent_ids) do
    case Map.get(game.players, player_id) do
      nil ->
        game

      player ->
        updated_player = %{player | used_talents: player.used_talents ++ talent_ids}
        %{game | players: Map.put(game.players, player_id, updated_player)}
    end
  end

  defp maybe_advance_turn(%__MODULE__{status: :playing, phase: :action} = game) do
    players = Map.values(game.players)

    cond do
      players == [] ->
        game

      Enum.all?(players, fn
        %Player{is_ready: ready} -> ready
        _ -> false
      end) ->
        # All players ready - advance to demurrage phase
        next_phase(game)

      true ->
        game
    end
  end

  defp maybe_advance_turn(game), do: game

  defp advance_to_next_player(%__MODULE__{phase: :action, player_order: []} = game), do: game

  defp advance_to_next_player(
         %__MODULE__{phase: :action, player_order: order, current_player_index: index} = game
       ) do
    next_index = rem(index + 1, length(order))
    %{game | current_player_index: next_index}
  end

  defp advance_to_next_player(game), do: game

  @doc """
  Gets the current player ID in action phase.
  """
  def get_current_player(%__MODULE__{
        phase: :action,
        player_order: order,
        current_player_index: index
      }) do
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

  defp set_phase(game, phase) do
    %{game | phase: phase}
  end

  defp get_next_phase(:event), do: :discussion
  defp get_next_phase(:discussion), do: :action
  defp get_next_phase(:action), do: :demurrage
  defp get_next_phase(:demurrage), do: :life_update
  defp get_next_phase(:life_update), do: :judgment
  # Next turn starts
  defp get_next_phase(:judgment), do: :event
  defp get_next_phase(_), do: :event

  defp execute_phase(%__MODULE__{status: :playing, phase: :event} = game) do
    game
    |> draw_and_apply_event()
    |> set_phase(:discussion)
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :discussion} = game) do
    # Discussion phase - players can discuss
    # Check if all players are ready to advance to action phase
    if all_players_discussion_ready?(game) do
      game
      |> add_log("All players ready - advancing to action phase")
      |> set_phase(:action)
    else
      game
    end
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :action} = game) do
    # Action phase - players can play cards
    # Initialize current player index to first player
    if game.current_player_index == 0 and game.player_order != [] do
      %{game | current_player_index: 0}
      |> add_log("Action phase started - #{get_current_player_name(game)}'s turn")
    else
      game
    end
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :demurrage} = game) do
    game
    |> apply_demurrage()
    |> set_phase(:life_update)

    # Don't recursively call execute_phase - let next_phase handle it
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :life_update} = game) do
    game
    |> reset_player_state()
    |> check_projects_unlock()
    |> update_life_index()
    |> set_phase(:judgment)

    # Don't recursively call execute_phase - let next_phase handle it
  end

  defp execute_phase(%__MODULE__{status: :playing, phase: :judgment} = game) do
    updated_game = check_win_loss(game)

    if updated_game.status == :playing do
      # Game continues - next turn starts with event phase
      # But don't execute event phase yet - that happens on next_turn
      set_phase(updated_game, :event)
    else
      # Game ended - stay in judgment phase
      set_phase(updated_game, :judgment)
    end
  end

  defp execute_phase(game), do: game

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

  defp is_project_completed?(game, project_id) do
    # Check if project is in completed_projects list
    project_id in game.completed_projects
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
  def in_phase?(%__MODULE__{} = game, phase) do
    game.phase == phase
  end
end
