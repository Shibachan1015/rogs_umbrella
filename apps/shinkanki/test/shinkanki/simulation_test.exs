defmodule Shinkanki.SimulationTest do
  use ExUnit.Case
  alias Shinkanki.Game

  @num_simulations 10
  @max_turns_per_game 25

  describe "game balance simulation" do
    test "simulates multiple games with random actions and collects statistics" do
      results =
        1..@num_simulations
        |> Enum.map(fn i ->
          simulate_game("sim_#{i}")
        end)

      stats = calculate_statistics(results)

      # Print statistics for manual review
      IO.puts("\n=== Game Balance Simulation Results ===")
      IO.puts("Total games: #{stats.total_games}")
      IO.puts("Won games: #{stats.won_games} (#{stats.win_rate}%)")
      IO.puts("Lost games: #{stats.lost_games} (#{stats.loss_rate}%)")
      IO.puts("Average turns: #{stats.avg_turns}")
      IO.puts("Average final Life Index: #{stats.avg_life_index}")
      IO.puts("Average final Currency: #{stats.avg_currency}")
      IO.puts("Average final Forest: #{stats.avg_forest}")
      IO.puts("Average final Culture: #{stats.avg_culture}")
      IO.puts("Average final Social: #{stats.avg_social}")
      IO.puts("========================================\n")

      # Basic assertions to ensure games are completing
      assert stats.total_games == @num_simulations
      assert stats.avg_turns > 0
      assert stats.avg_turns <= @max_turns_per_game
    end
  end

  defp simulate_game(room_id) do
    game = Game.new(room_id)
    {:ok, game} = Game.join(game, "p1", "Player 1")

    simulate_until_end(game, game.turn, 0)
  end

  defp simulate_until_end(game, _last_turn, iterations) when iterations >= 1000 do
    # Prevent infinite loops - force end after too many iterations
    %{game | status: :lost}
  end

  defp simulate_until_end(game, _last_turn, _iterations) when game.turn >= @max_turns_per_game do
    # Force end if max turns reached
    %{game | status: :lost}
  end

  defp simulate_until_end(game, last_turn, iterations) do
    case game.status do
      :playing ->
        # Try to play a random action from hand
        hand = Map.get(game.hands, "p1", [])

        new_game =
          if hand != [] do
            # Randomly select a card from hand
            card_id = Enum.random(hand)

            case Game.play_action(game, "p1", card_id, []) do
              {:ok, updated_game} ->
                updated_game

              _ ->
                # If play_action failed, advance turn manually
                Game.next_turn(game)
            end
          else
            # No cards in hand, advance turn
            Game.next_turn(game)
          end

        # Prevent infinite loops by checking if turn actually advanced
        if new_game.turn > last_turn or new_game.status != :playing do
          simulate_until_end(new_game, new_game.turn, iterations + 1)
        else
          # Force turn advancement if stuck
          forced_game = Game.next_turn(game)
          simulate_until_end(forced_game, forced_game.turn, iterations + 1)
        end

      _ ->
        # Game ended (won or lost)
        game
    end
  end

  defp calculate_statistics(results) do
    total = length(results)
    won = Enum.count(results, &(&1.status == :won))
    lost = Enum.count(results, &(&1.status == :lost))

    %{
      total_games: total,
      won_games: won,
      lost_games: lost,
      win_rate: if(total > 0, do: Float.round(won / total * 100, 1), else: 0.0),
      loss_rate: if(total > 0, do: Float.round(lost / total * 100, 1), else: 0.0),
      avg_turns: calculate_average(results, & &1.turn),
      avg_life_index: calculate_average(results, & &1.life_index),
      avg_currency: calculate_average(results, & &1.currency),
      avg_forest: calculate_average(results, & &1.forest),
      avg_culture: calculate_average(results, & &1.culture),
      avg_social: calculate_average(results, & &1.social)
    }
  end

  defp calculate_average(results, extractor) do
    if Enum.empty?(results) do
      0.0
    else
      results
      |> Enum.map(extractor)
      |> Enum.sum()
      |> Kernel./(length(results))
      |> Float.round(1)
    end
  end
end
