defmodule Shinkanki.GameServer do
  use GenServer
  alias Shinkanki.Game

  # Client API

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  def get_state(room_id) do
    GenServer.call(via_tuple(room_id), :get_state)
  end

  def next_turn(room_id) do
    GenServer.call(via_tuple(room_id), :next_turn)
  end

  def update_stats(room_id, changes) do
    GenServer.call(via_tuple(room_id), {:update_stats, changes})
  end

  defp via_tuple(room_id) do
    {:via, Registry, {Shinkanki.GameRegistry, room_id}}
  end

  # Server Callbacks

  @impl true
  def init(room_id) do
    {:ok, Game.new(room_id)}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:next_turn, _from, game) do
    new_game = Game.next_turn(game)
    broadcast_state(new_game)
    {:reply, new_game, new_game}
  end

  @impl true
  def handle_call({:update_stats, changes}, _from, game) do
    new_game = Game.update_stats(game, changes)
    broadcast_state(new_game)
    {:reply, new_game, new_game}
  end

  defp broadcast_state(game) do
    Phoenix.PubSub.broadcast(
      Shinkanki.PubSub,
      "shinkanki:game:#{game.room_id}",
      {:game_state_updated, game}
    )
  end
end
