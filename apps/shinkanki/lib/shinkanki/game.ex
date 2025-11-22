defmodule Shinkanki.Game do
  @moduledoc """
  Represents the core game state and pure logic for Shinkanki.
  """

  defstruct [
    :room_id,
    turn: 1,
    forest: 50,   # Forest (F)
    culture: 50,  # Culture (K)
    social: 50,   # Social (S)
    currency: 100, # Currency (P)
    life_index: 150, # Life Index (L) = F + K + S
    status: :playing, # :playing, :won, :lost
    logs: []
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
          logs: list()
        }

  @doc """
  Creates a new game state.
  """
  def new(room_id) do
    %__MODULE__{room_id: room_id}
  end

  @doc """
  Advances the game to the next turn.
  Applies demurrage to currency and checks win/loss conditions.
  """
  def next_turn(%__MODULE__{status: :playing} = game) do
    game
    |> apply_demurrage()
    |> advance_turn_counter()
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
    |> update_life_index()
    |> check_win_loss()
  end
  def update_stats(game, _changes), do: game

  defp apply_demurrage(game) do
    # Demurrage: floor(P * 0.9)
    new_currency = floor(game.currency * 0.9)
    %{game | currency: new_currency}
  end

  defp advance_turn_counter(game) do
    # Increment turn to indicate progression.
    # If turn goes from 20 to 21, it means the game has ended.
    %{game | turn: game.turn + 1}
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
      # Loss condition: Any of F, K, S becomes 0 or less
      game.forest <= 0 or game.culture <= 0 or game.social <= 0 ->
        %{game | status: :lost}

      # Win/Loss condition at end of game (after turn 20)
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
end
