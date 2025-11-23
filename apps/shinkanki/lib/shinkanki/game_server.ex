defmodule Shinkanki.GameServer do
  use GenServer
  alias Shinkanki.{Game, ActionLog, AI}

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

  def play_card(room_id, card_id) do
    GenServer.call(via_tuple(room_id), {:play_card, card_id})
  end

  def play_action(room_id, player_id, action_id, talent_ids \\ []) do
    GenServer.call(via_tuple(room_id), {:play_action, player_id, action_id, talent_ids})
  end

  def join_player(room_id, player_id, name, talent_ids \\ nil) do
    GenServer.call(via_tuple(room_id), {:join_player, player_id, name, talent_ids})
  end

  def ai_turn(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:ai_turn, player_id})
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
    log_action(new_game, "next_turn", nil, %{})
    broadcast_state(new_game)
    {:reply, new_game, new_game}
  end

  @impl true
  def handle_call({:update_stats, changes}, _from, game) do
    new_game = Game.update_stats(game, changes)
    log_action(new_game, "update_stats", nil, %{changes: changes})
    broadcast_state(new_game)
    {:reply, new_game, new_game}
  end

  @impl true
  def handle_call({:play_card, card_id}, _from, game) do
    case Game.play_card(game, card_id) do
      {:ok, new_game} ->
        log_action(new_game, "play_card", nil, %{card_id: card_id})
        broadcast_state(new_game)
        {:reply, {:ok, new_game}, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:play_action, player_id, action_id, talent_ids}, _from, game) do
    case Game.play_action(game, player_id, action_id, talent_ids) do
      {:ok, new_game} = ok ->
        log_action(new_game, "play_action", player_id, %{action_id: action_id, talent_ids: talent_ids})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:join_player, player_id, name, talent_ids}, _from, game) do
    case Game.join(game, player_id, name, talent_ids) do
      {:ok, new_game} = ok ->
        log_action(new_game, "join_player", player_id, %{name: name, talent_ids: talent_ids})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:ai_turn, player_id}, _from, game) do
    case AI.select_action(game, player_id) do
      {:ok, action_id, talent_ids} ->
        case Game.play_action(game, player_id, action_id, talent_ids) do
          {:ok, new_game} = ok ->
            log_action(new_game, "play_action", player_id, %{action_id: action_id, talent_ids: talent_ids})
            broadcast_state(new_game)
            {:reply, ok, new_game}

          error ->
            {:reply, error, game}
        end

      error ->
        {:reply, error, game}
    end
  end

  defp broadcast_state(game) do
    Phoenix.PubSub.broadcast(
      Shinkanki.PubSub,
      "shinkanki:game:#{game.room_id}",
      {:game_state_updated, game}
    )
  end

  defp log_action(game, action, player_id, payload) do
    # Only log if Repo is available (not in test environment)
    if Code.ensure_loaded?(Shinkanki.Repo) and function_exported?(Shinkanki.Repo, :insert, 2) do
      try do
        %ActionLog{}
        |> ActionLog.changeset(%{
          room_id: game.room_id,
          turn: game.turn,
          player_id: player_id,
          action: action,
          payload: payload
        })
        |> Shinkanki.Repo.insert()
      rescue
        _ -> :ok
      end
    else
      :ok
    end
  end
end
