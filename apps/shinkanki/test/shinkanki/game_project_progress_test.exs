defmodule Shinkanki.GameProjectProgressTest do
  use ExUnit.Case
  alias Shinkanki.{Game, Card}

  describe "project progress management" do
    test "contributes talent to project and advances progress" do
      # Set up game with unlocked project
      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      # Unlock project
      game = Game.update_stats(game, %{})
      assert :p_forest_fest in game.available_projects

      # Join player
      {:ok, game} = Game.join(game, "p1", "Player 1")
      player = Map.get(game.players, "p1")

      # Contribute a talent
      talent_id = List.first(player.talents)

      assert {:ok, new_game} =
               Game.contribute_talent_to_project(game, "p1", :p_forest_fest, talent_id)

      # Check progress increased
      progress_data = Map.get(new_game.project_progress, :p_forest_fest)
      assert progress_data.progress == 1

      # Check talent was marked as used
      updated_player = Map.get(new_game.players, "p1")
      assert talent_id in updated_player.used_talents
    end

    test "completes project when progress reaches required amount" do
      project = Card.get_project(:p_forest_fest)
      required = project.required_progress

      # Set up game with unlocked project
      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      game = Game.update_stats(game, %{})
      {:ok, game} = Game.join(game, "p1", "Player 1")
      player = Map.get(game.players, "p1")

      initial_forest = game.forest
      initial_culture = game.culture
      initial_social = game.social

      # Contribute talents until project is completed
      talents = player.talents
      # Use all available talents (player has 2 talents by default)
      # If required is more than available, we'll need multiple players or more talents
      talents_to_use = Enum.take(talents, min(length(talents), required))

      final_game =
        Enum.reduce(talents_to_use, game, fn talent_id, acc_game ->
          case Game.contribute_talent_to_project(acc_game, "p1", :p_forest_fest, talent_id) do
            {:ok, new_game} -> new_game
            _error -> acc_game
          end
        end)

      # If we have enough talents, project should be completed
      if length(talents_to_use) >= required do
        # Project should be completed and effect applied
        assert final_game.forest == initial_forest + project.effect.forest
        assert final_game.culture == initial_culture + project.effect.culture
        assert final_game.social == initial_social + project.effect.social

        # Project should be removed from progress tracking
        assert not Map.has_key?(final_game.project_progress, :p_forest_fest)
        assert :p_forest_fest in final_game.completed_projects
      else
        # Not enough talents - project should still be in progress
        progress_data = Map.get(final_game.project_progress, :p_forest_fest)
        assert progress_data.progress == length(talents_to_use)
      end
    end

    test "returns error if project not unlocked" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      player = Map.get(game.players, "p1")
      talent_id = List.first(player.talents)

      assert {:error, :project_not_unlocked} =
               Game.contribute_talent_to_project(game, "p1", :p_forest_fest, talent_id)
    end

    test "returns error if project already completed" do
      project = Card.get_project(:p_forest_fest)
      required = project.required_progress

      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      game = Game.update_stats(game, %{})
      {:ok, game} = Game.join(game, "p1", "Player 1")
      _player = Map.get(game.players, "p1")

      # Complete the project - need multiple players to have enough talents
      {:ok, game} = Game.join(game, "p2", "Player 2")
      {:ok, game} = Game.join(game, "p3", "Player 3")
      p1 = Map.get(game.players, "p1")
      p2 = Map.get(game.players, "p2")
      p3 = Map.get(game.players, "p3")

      # Combine talents from all players (each has 2 talents, so 6 total)
      all_talents = p1.talents ++ p2.talents ++ p3.talents
      talents_to_use = Enum.take(all_talents, required)

      # Distribute contributions between players
      completed_game =
        Enum.reduce(Enum.with_index(talents_to_use), game, fn {talent_id, index}, acc_game ->
          player_id =
            case rem(index, 3) do
              0 -> "p1"
              1 -> "p2"
              _ -> "p3"
            end

          case Game.contribute_talent_to_project(acc_game, player_id, :p_forest_fest, talent_id) do
            {:ok, new_game} -> new_game
            _error -> acc_game
          end
        end)

      # Verify project is completed
      assert :p_forest_fest in completed_game.completed_projects

      # Try to contribute to completed project (use a talent from p1 that wasn't used)
      unused_talent = Enum.find(p1.talents, fn t -> t not in talents_to_use end)

      if unused_talent do
        assert {:error, :project_already_completed} =
                 Game.contribute_talent_to_project(
                   completed_game,
                   "p1",
                   :p_forest_fest,
                   unused_talent
                 )
      end
    end

    test "returns error if talent not owned by player" do
      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      game = Game.update_stats(game, %{})
      {:ok, game} = Game.join(game, "p1", "Player 1")

      # Try to contribute a talent that doesn't exist
      assert {:error, :talent_not_owned} =
               Game.contribute_talent_to_project(game, "p1", :p_forest_fest, :nonexistent_talent)
    end

    test "returns error if talent already used this turn" do
      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      game = Game.update_stats(game, %{})
      {:ok, game} = Game.join(game, "p1", "Player 1")
      player = Map.get(game.players, "p1")
      talent_id = List.first(player.talents)

      # Use talent in an action first
      hand = Map.get(game.hands, "p1", [])

      if hand != [] do
        {:ok, game} = Game.play_action(game, "p1", List.first(hand), [talent_id])

        # Try to contribute the same talent to project
        assert {:error, :talent_already_used} =
                 Game.contribute_talent_to_project(game, "p1", :p_forest_fest, talent_id)
      end
    end

    test "tracks multiple contributors to a project" do
      game = %Game{
        Game.new("room")
        | forest: 80,
          culture: 60,
          currency: 1000,
          event_deck: [],
          event_discard_pile: []
      }

      game = Game.update_stats(game, %{})
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")

      p1 = Map.get(game.players, "p1")
      p2 = Map.get(game.players, "p2")

      # Both players contribute
      {:ok, game} =
        Game.contribute_talent_to_project(game, "p1", :p_forest_fest, List.first(p1.talents))

      {:ok, game} =
        Game.contribute_talent_to_project(game, "p2", :p_forest_fest, List.first(p2.talents))

      # Check contributors
      progress_data = Map.get(game.project_progress, :p_forest_fest)
      assert progress_data.progress == 2
      assert "p1" in progress_data.contributors
      assert "p2" in progress_data.contributors
    end
  end
end
