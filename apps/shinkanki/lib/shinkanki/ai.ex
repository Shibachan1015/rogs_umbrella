defmodule Shinkanki.AI do
  @moduledoc """
  AI player logic for NPCs in single-player mode.
  """

  alias Shinkanki.{Game, Card}

  @doc """
  Selects the best action for an AI player given the current game state.
  Returns {:ok, action_id, talent_ids} or {:error, reason}.
  """
  def select_action(%Game{} = game, player_id) do
    player = Map.get(game.players, player_id)

    cond do
      is_nil(player) ->
        {:error, :player_not_found}

      player.is_ready ->
        {:error, :already_ready}

      game.status != :playing ->
        {:error, :game_over}

      true ->
        hand = Map.get(game.hands, player_id, [])
        select_best_card(game, player, hand)
    end
  end

  defp select_best_card(_game, _player, []) do
    # No cards in hand - cannot play
    {:error, :no_cards}
  end

  defp select_best_card(game, player, hand) do
    # Filter cards that can be played (affordable and in hand)
    playable_cards =
      hand
      |> Enum.map(fn card_id ->
        case Card.get_action(card_id) do
          nil ->
            # Check if it's a project
            case Card.get_project(card_id) do
              nil -> nil
              project ->
                if project.id in game.available_projects and game.currency >= project.cost do
                  {project, card_id}
                else
                  nil
                end
            end

          action ->
            if game.currency >= action.cost do
              {action, card_id}
            else
              nil
            end
        end
      end)
      |> Enum.reject(&is_nil/1)

    case playable_cards do
      [] ->
        {:error, :no_affordable_cards}

      cards ->
        # Select the card with the best score
        {best_card, card_id} = select_by_score(game, player, cards)
        talent_ids = select_talents(player, best_card)

        {:ok, card_id, talent_ids}
    end
  end

  defp select_by_score(game, player, cards) do
    cards
    |> Enum.map(fn {card, card_id} ->
      score = calculate_card_score(game, player, card)
      {score, {card, card_id}}
    end)
    |> Enum.max_by(fn {score, _} -> score end)
    |> elem(1)
  end

  defp calculate_card_score(game, _player, card) do
    # Simple scoring: prioritize cards that increase Life Index (F + K + S)
    effect = card.effect || %{}
    life_index_gain = (effect[:forest] || 0) + (effect[:culture] || 0) + (effect[:social] || 0)

    # Prefer cards that don't cost too much relative to their effect
    cost_ratio = if card.cost > 0, do: life_index_gain / card.cost, else: life_index_gain

    # Bonus for cards that help maintain balance (prevent any stat from going too low)
    balance_bonus =
      cond do
        game.forest < 20 and effect[:forest] && effect[:forest] > 0 -> 5
        game.culture < 20 and effect[:culture] && effect[:culture] > 0 -> 5
        game.social < 20 and effect[:social] && effect[:social] > 0 -> 5
        true -> 0
      end

    life_index_gain + cost_ratio * 2 + balance_bonus
  end

  defp select_talents(player, card) do
    # Select talents that are compatible with the card's tags
    available_talents =
      player.talents
      |> Enum.reject(&Enum.member?(player.used_talents, &1))
      |> Enum.map(&Card.get_talent/1)
      |> Enum.reject(&is_nil/1)

    compatible_talents =
      available_talents
      |> Enum.filter(fn talent ->
        Enum.any?(talent.compatible_tags, &Enum.member?(card.tags || [], &1))
      end)

    # Use up to 2 compatible talents
    compatible_talents
    |> Enum.take(2)
    |> Enum.map(& &1.id)
  end
end
