defmodule Shinkanki do
  @moduledoc """
  Shinkanki keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Shinkanki.GameServer

  @doc """
  Starts a new game session for the given room_id.
  """
  def start_game(room_id) do
    DynamicSupervisor.start_child(Shinkanki.GameSupervisor, {GameServer, room_id})
  end

  @doc """
  Gets the current game state for the given room_id.
  Returns nil if the game is not running.
  """
  def get_current_state(room_id) do
    case Registry.lookup(Shinkanki.GameRegistry, room_id) do
      [{_pid, _}] -> GameServer.get_state(room_id)
      [] -> nil
    end
  end

  @doc """
  Advances the game to the next turn.
  """
  def next_turn(room_id) do
    call_server(room_id, fn -> GameServer.next_turn(room_id) end)
  end

  @doc """
  Updates the game statistics manually.
  """
  def update_stats(room_id, changes) do
    call_server(room_id, fn -> GameServer.update_stats(room_id, changes) end)
  end

  @doc """
  Subscribes the current process to game updates for the given room_id.
  """
  def subscribe_game(room_id) do
    Phoenix.PubSub.subscribe(Shinkanki.PubSub, "shinkanki:game:#{room_id}")
  end

  defp call_server(room_id, fun) do
    case Registry.lookup(Shinkanki.GameRegistry, room_id) do
      [{_pid, _}] -> fun.()
      [] -> {:error, :game_not_found}
    end
  end
end
