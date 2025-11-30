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

  def next_phase(room_id) do
    GenServer.call(via_tuple(room_id), :next_phase)
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

  def join_player(room_id, player_id, name, avatar \\ "🎮", talent_ids \\ nil) do
    GenServer.call(via_tuple(room_id), {:join_player, player_id, name, avatar, talent_ids})
  end

  def ai_turn(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:ai_turn, player_id})
  end

  def contribute_talent_to_project(room_id, player_id, project_id, talent_id) do
    GenServer.call(
      via_tuple(room_id),
      {:contribute_talent_to_project, player_id, project_id, talent_id}
    )
  end

  def mark_discussion_ready(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:mark_discussion_ready, player_id})
  end

  def toggle_waiting_ready(room_id, player_id) do
    GenServer.call(via_tuple(room_id), {:toggle_waiting_ready, player_id})
  end

  def start_game(room_id) do
    GenServer.call(via_tuple(room_id), :start_game)
  end

  def start_game_with_ai(room_id) do
    GenServer.call(via_tuple(room_id), :start_game_with_ai)
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
  def handle_call(:next_phase, _from, game) do
    new_game = Game.next_phase(game)
    log_action(new_game, "next_phase", nil, %{phase: new_game.phase})
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
        log_action(new_game, "play_action", player_id, %{
          action_id: action_id,
          talent_ids: talent_ids
        })

        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:join_player, player_id, name, avatar, talent_ids}, _from, game) do
    case Game.join(game, player_id, name, avatar, talent_ids) do
      {:ok, new_game} = ok ->
        log_action(new_game, "join_player", player_id, %{name: name, avatar: avatar, talent_ids: talent_ids})
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
            log_action(new_game, "play_action", player_id, %{
              action_id: action_id,
              talent_ids: talent_ids
            })

            broadcast_state(new_game)
            {:reply, ok, new_game}

          error ->
            {:reply, error, game}
        end

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:contribute_talent_to_project, player_id, project_id, talent_id}, _from, game) do
    case Game.contribute_talent_to_project(game, player_id, project_id, talent_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "contribute_talent_to_project", player_id, %{
          project_id: project_id,
          talent_id: talent_id
        })

        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:mark_discussion_ready, player_id}, _from, game) do
    case Game.mark_discussion_ready(game, player_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "mark_discussion_ready", player_id, %{})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:toggle_waiting_ready, player_id}, _from, game) do
    case Game.toggle_waiting_ready(game, player_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "toggle_waiting_ready", player_id, %{})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:start_game, _from, game) do
    case Game.start_game(game) do
      {:ok, new_game} = ok ->
        log_action(new_game, "start_game", nil, %{})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:start_game_with_ai, _from, game) do
    case Game.start_game_with_ai(game) do
      {:ok, new_game} = ok ->
        ai_count = Enum.count(new_game.players, fn {_id, p} -> p.is_ai end)
        log_action(new_game, "start_game_with_ai", nil, %{ai_count: ai_count})
        broadcast_state(new_game)
        {:reply, ok, new_game}

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

    # Trigger AI actions if it's an AI player's turn
    maybe_trigger_ai(game)
  end

  defp maybe_trigger_ai(game) do
    if game.status == :playing do
      case game.phase do
        :discussion ->
          # AI players auto-ready during discussion phase
          trigger_ai_discussion_ready(game)

        :action ->
          # AI player takes their turn during action phase
          trigger_ai_action(game)

        _ ->
          :ok
      end
    end
  end

  defp trigger_ai_discussion_ready(game) do
    # Find AI players who are not ready yet
    ai_not_ready =
      game.players
      |> Enum.filter(fn {_id, player} -> player.is_ai && !player.is_ready end)
      |> Enum.map(fn {id, _} -> id end)

    # Schedule AI players to mark ready after a short delay
    Enum.each(ai_not_ready, fn player_id ->
      Process.send_after(self(), {:ai_discussion_ready, player_id}, 500)
    end)
  end

  defp trigger_ai_action(game) do
    # Get current player
    current_player_id = get_current_player_id(game)

    if current_player_id do
      case Map.get(game.players, current_player_id) do
        %{is_ai: true} ->
          # Schedule AI action after a short delay
          Process.send_after(self(), {:ai_take_action, current_player_id}, 800)

        _ ->
          :ok
      end
    end
  end

  defp get_current_player_id(game) do
    player_order = Map.keys(game.players) |> Enum.sort()
    current_index = rem(game.current_player_index || 0, length(player_order))
    Enum.at(player_order, current_index)
  end

  # Handle AI discussion ready
  @impl true
  def handle_info({:ai_discussion_ready, player_id}, game) do
    case Game.mark_discussion_ready(game, player_id) do
      {:ok, new_game} ->
        log_action(new_game, "ai_discussion_ready", player_id, %{})
        broadcast_state(new_game)
        {:noreply, new_game}

      _ ->
        {:noreply, game}
    end
  end

  # Handle AI taking action
  @impl true
  def handle_info({:ai_take_action, player_id}, game) do
    case AI.select_action(game, player_id) do
      {:ok, action_id, talent_ids} ->
        case Game.play_action(game, player_id, action_id, talent_ids) do
          {:ok, new_game} ->
            log_action(new_game, "ai_play_action", player_id, %{
              action_id: action_id,
              talent_ids: talent_ids
            })
            broadcast_state(new_game)
            {:noreply, new_game}

          _ ->
            # If action failed, try to skip turn or pass
            {:noreply, game}
        end

      {:error, :no_affordable_cards} ->
        # AI can't afford any cards, advance to next phase/player
        case Game.next_phase(game) do
          {:ok, new_game} ->
            log_action(new_game, "ai_skip_turn", player_id, %{reason: :no_affordable_cards})
            broadcast_state(new_game)
            {:noreply, new_game}

          _ ->
            {:noreply, game}
        end

      {:error, :no_cards} ->
        # AI has no cards, advance to next phase
        case Game.next_phase(game) do
          {:ok, new_game} ->
            log_action(new_game, "ai_skip_turn", player_id, %{reason: :no_cards})
            broadcast_state(new_game)
            {:noreply, new_game}

          _ ->
            {:noreply, game}
        end

      _ ->
        {:noreply, game}
    end
  end

  @impl true
  def handle_info(_msg, game), do: {:noreply, game}

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
