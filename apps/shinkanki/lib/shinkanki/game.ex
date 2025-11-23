defmodule Shinkanki.Game do
  @moduledoc """
  Represents the core game state and pure logic for Shinkanki.
  """

  alias Shinkanki.{Card, Player}

  @initial_hand_size 3
  @max_talents_per_action 2
  @deck_cycles 3

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
    # :playing, :won, :lost
    status: :playing,
    logs: [],
    players: %{},
    deck: [],
    discard_pile: [],
    hands: %{},
    available_projects: [],
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
          status: :playing | :won | :lost,
          logs: list(),
          players: %{optional(String.t()) => Player.t()},
          deck: list(atom()),
          discard_pile: list(atom()),
          hands: %{optional(String.t()) => list(atom())},
          available_projects: list(atom()),
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
  Adds a player to the game. If talents are not provided, two default talents are assigned.
  """
  def join(%__MODULE__{} = game, player_id, name, talent_ids \\ nil) do
    cond do
      game.status != :playing ->
        {:error, :game_over}

      Map.has_key?(game.players, player_id) ->
        {:error, :already_joined}

      true ->
        talents = prepare_talents(talent_ids)

        player =
          Player.new(player_id, name)
          |> Map.put(:talents, talents)

        game_with_player = %{game | players: Map.put(game.players, player_id, player)}

        {:ok,
         game_with_player
         |> draw_cards(player_id, @initial_hand_size)}
    end
  end

  @doc """
  Advances the game to the next turn.
  Draws an event card, applies demurrage to currency, resets players, and checks win/loss conditions.
  """
  def next_turn(%__MODULE__{status: :playing} = game) do
    game
    |> clear_current_event()
    |> advance_turn_counter()
    |> draw_and_apply_event()
    |> apply_demurrage()
    |> reset_player_state()
    |> check_projects_unlock()
    |> update_life_index()
    |> check_win_loss()
  end

  def next_turn(game), do: game

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
  Plays an action or project card with optional talent boosters.
  """
  def play_action(%__MODULE__{} = game, player_id, action_id, talent_ids \\ []) do
    with {:status, :playing} <- {:status, game.status},
         {:player, %Player{} = player} <- {:player, Map.get(game.players, player_id)},
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
        |> maybe_advance_turn()

      {:ok, new_game}
    else
      {:status, _} -> {:error, :game_over}
      {:player, nil} -> {:error, :player_not_found}
      {:action, {:error, reason}} -> {:error, reason}
      {:hand, {:error, reason}} -> {:error, reason}
      {:currency, false} -> {:error, :not_enough_currency}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_request}
    end
  end

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
      game.forest <= 0 or game.culture <= 0 or game.social <= 0 ->
        %{game | status: :lost}

      game.turn > 20 ->
        if game.life_index >= 40 do
          %{game | status: :won}
        else
          %{game | status: :lost}
        end

      true ->
        game
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

  defp maybe_advance_turn(%__MODULE__{} = game) do
    players = Map.values(game.players)

    cond do
      players == [] ->
        game

      Enum.all?(players, fn
        %Player{is_ready: ready} -> ready
        _ -> false
      end) ->
        next_turn(game)

      true ->
        game
    end
  end

  defp reset_player_state(game) do
    players =
      Enum.into(game.players, %{}, fn {id, player} ->
        {id, %{player | is_ready: false, used_talents: []}}
      end)

    %{game | players: players}
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
        {Enum.reverse(acc), game}

      discard ->
        reshuffled = Enum.shuffle(discard)
        take_from_deck(%{game | deck: reshuffled, discard_pile: []}, count, acc)
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
end
