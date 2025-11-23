defmodule Shinkanki.GameStartConditionTest do
  use ExUnit.Case
  alias Shinkanki.Game

  describe "game start conditions" do
    test "game starts in waiting status" do
      game = Game.new("room")
      assert game.status == :waiting
    end

    test "can_start? returns true when minimum players joined" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      assert Game.can_start?(game) == true
    end

    test "can_start? returns false when no players joined" do
      game = Game.new("room")
      assert Game.can_start?(game) == false
    end

    test "can_start? returns false when too many players joined" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")
      {:ok, game} = Game.join(game, "p3", "Player 3")
      {:ok, game} = Game.join(game, "p4", "Player 4")
      # Try to join 5th player - should fail
      assert {:error, :max_players_reached} = Game.join(game, "p5", "Player 5")
      # Game should still have 4 players
      assert length(game.player_order) == 4
      assert Game.can_start?(game) == true
    end

    test "start_game succeeds with minimum players" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")

      {:ok, started_game} = Game.start_game(game)
      assert started_game.status == :playing
      assert Enum.any?(started_game.logs, fn log -> String.contains?(log, "Game started") end)
    end

    test "start_game fails with no players" do
      game = Game.new("room")
      assert {:error, :not_enough_players} = Game.start_game(game)
    end

    test "start_game fails when game already started" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.start_game(game)

      assert {:error, :game_already_started} = Game.start_game(game)
    end

    test "start_game fails when game is over" do
      game = %Game{Game.new("room") | status: :won}
      assert {:error, :game_over} = Game.start_game(game)
    end

    test "join fails when game already started" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.start_game(game)

      assert {:error, :game_already_started} = Game.join(game, "p2", "Player 2")
    end

    test "join fails when max players reached" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")
      {:ok, game} = Game.join(game, "p3", "Player 3")
      {:ok, game} = Game.join(game, "p4", "Player 4")

      assert {:error, :max_players_reached} = Game.join(game, "p5", "Player 5")
    end

    test "start_game works with maximum players" do
      game = Game.new("room")
      {:ok, game} = Game.join(game, "p1", "Player 1")
      {:ok, game} = Game.join(game, "p2", "Player 2")
      {:ok, game} = Game.join(game, "p3", "Player 3")
      {:ok, game} = Game.join(game, "p4", "Player 4")

      {:ok, started_game} = Game.start_game(game)
      assert started_game.status == :playing
    end
  end
end

