ExUnit.start()
# Ecto.Adapters.SQL.Sandbox.mode(Shinkanki.Repo, :manual)

# Define game test helpers
defmodule Shinkanki.GameTestHelpers do
  @moduledoc """
  Helper functions for Shinkanki game tests.
  """

  alias Shinkanki.Game

  @doc """
  Creates a game in :playing status for testing.
  """
  def playing_game(room_id, attrs \\ %{}) do
    base = %Game{Game.new(room_id) | status: :playing}
    struct(base, attrs)
  end

  @doc """
  Creates a game with a player already joined and game started.
  """
  def started_game_with_player(room_id, player_id, player_name \\ "Test Player") do
    game = Game.new(room_id)
    {:ok, game} = Game.join(game, player_id, player_name)
    {:ok, game} = Game.start_game(game)
    game
  end
end
