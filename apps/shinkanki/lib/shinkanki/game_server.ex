defmodule Shinkanki.GameServer do
  @moduledoc """
  GenServer for managing a single game session's state and handling game logic interactions.
  """
  use GenServer
  alias Shinkanki.{Game, ActionLog, AI}
  alias Shinkanki.AI.ClaudeAgent

  require Logger

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

  # === 連携カードAPI ===

  def initiate_renkei(room_id, player_id, renkei_card_id) do
    GenServer.call(via_tuple(room_id), {:initiate_renkei, player_id, renkei_card_id})
  end

  def join_renkei(room_id, player_id, renkei_card_id) do
    GenServer.call(via_tuple(room_id), {:join_renkei, player_id, renkei_card_id})
  end

  def cancel_renkei(room_id, player_id, renkei_card_id) do
    GenServer.call(via_tuple(room_id), {:cancel_renkei, player_id, renkei_card_id})
  end

  def get_available_renkei(room_id) do
    GenServer.call(via_tuple(room_id), :get_available_renkei)
  end

  def get_pending_renkei(room_id) do
    GenServer.call(via_tuple(room_id), :get_pending_renkei)
  end

  def get_orochi_status(room_id) do
    GenServer.call(via_tuple(room_id), :get_orochi_status)
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
        log_action(new_game, "join_player", player_id, %{
          name: name,
          avatar: avatar,
          talent_ids: talent_ids
        })

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

  # === 連携カードのhandle_call ===

  @impl true
  def handle_call({:initiate_renkei, player_id, renkei_card_id}, _from, game) do
    case Game.initiate_renkei(game, player_id, renkei_card_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "initiate_renkei", player_id, %{renkei_card_id: renkei_card_id})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:join_renkei, player_id, renkei_card_id}, _from, game) do
    case Game.join_renkei(game, player_id, renkei_card_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "join_renkei", player_id, %{renkei_card_id: renkei_card_id})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call({:cancel_renkei, player_id, renkei_card_id}, _from, game) do
    case Game.cancel_renkei(game, player_id, renkei_card_id) do
      {:ok, new_game} = ok ->
        log_action(new_game, "cancel_renkei", player_id, %{renkei_card_id: renkei_card_id})
        broadcast_state(new_game)
        {:reply, ok, new_game}

      error ->
        {:reply, error, game}
    end
  end

  @impl true
  def handle_call(:get_available_renkei, _from, game) do
    renkei_cards = Game.available_renkei_cards(game)
    {:reply, renkei_cards, game}
  end

  @impl true
  def handle_call(:get_pending_renkei, _from, game) do
    pending = Game.pending_renkei_list(game)
    {:reply, pending, game}
  end

  @impl true
  def handle_call(:get_orochi_status, _from, game) do
    status = Game.orochi_status(game)
    {:reply, status, game}
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

    # Schedule AI players to share their thoughts and mark ready after delays
    ai_not_ready
    |> Enum.with_index()
    |> Enum.each(fn {player_id, index} ->
      # Stagger AI messages to make conversation feel natural
      delay = 1000 + index * 1500
      Process.send_after(self(), {:ai_discussion_speak, player_id}, delay)
      Process.send_after(self(), {:ai_discussion_ready, player_id}, delay + 500)
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
    case Game.get_current_player(game) do
      nil ->
        order = game.player_order

        if order == [] do
          nil
        else
          current_index = rem(game.current_player_index, length(order))
          Enum.at(order, current_index)
        end

      player_id ->
        player_id
    end
  end

  # Handle AI speaking during discussion
  @impl true
  def handle_info({:ai_discussion_speak, player_id}, game) do
    {:ok, message} = ClaudeAgent.discuss(game, player_id)
    broadcast_ai_chat(game, player_id, message)
    {:noreply, game}
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

  # Handle AI taking action with Claude Agent
  @impl true
  def handle_info({:ai_take_action, player_id}, game) do
    # Use Claude Agent for action decision with thoughts
    case ClaudeAgent.decide_action(game, player_id) do
      {:ok, action_id, talent_ids, thought} ->
        # Broadcast AI's thought as chat message
        broadcast_ai_chat(game, player_id, thought)

        case Game.play_action(game, player_id, action_id, talent_ids) do
          {:ok, new_game} ->
            log_action(new_game, "ai_play_action", player_id, %{
              action_id: action_id,
              talent_ids: talent_ids,
              thought: thought
            })

            broadcast_state(new_game)
            {:noreply, new_game}

          _ ->
            # If action failed, try to skip turn or pass
            {:noreply, game}
        end

      {:error, :no_affordable_cards} ->
        # Broadcast AI's inability to act
        player = Map.get(game.players, player_id)

        if player do
          ai_index = get_ai_index(game, player_id)
          message = get_skip_message(ai_index, :no_affordable_cards)
          broadcast_ai_chat(game, player_id, message)
        end

        # Mark AI as ready so turn can advance
        {:ok, new_game} = Game.mark_player_ready_for_action(game, player_id)
        log_action(new_game, "ai_skip_turn", player_id, %{reason: :no_affordable_cards})
        broadcast_state(new_game)
        {:noreply, new_game}

      {:error, :no_cards} ->
        # Broadcast AI's inability to act
        player = Map.get(game.players, player_id)

        if player do
          ai_index = get_ai_index(game, player_id)
          message = get_skip_message(ai_index, :no_cards)
          broadcast_ai_chat(game, player_id, message)
        end

        {:ok, new_game} = Game.mark_player_ready_for_action(game, player_id)
        log_action(new_game, "ai_skip_turn", player_id, %{reason: :no_cards})
        broadcast_state(new_game)
        {:noreply, new_game}

      _ ->
        {:noreply, game}
    end
  end

  @impl true
  def handle_info(_msg, game), do: {:noreply, game}

  # Broadcast AI chat message to all subscribers
  defp broadcast_ai_chat(game, player_id, message) do
    Phoenix.PubSub.broadcast(
      Shinkanki.PubSub,
      "shinkanki:game:#{game.room_id}",
      {:ai_chat_message, %{player_id: player_id, message: message, timestamp: DateTime.utc_now()}}
    )
  end

  # Get AI player index (1-4) for character selection
  defp get_ai_index(game, player_id) do
    ai_players =
      game.player_order
      |> Enum.filter(fn id ->
        player = Map.get(game.players, id)
        player && player.is_ai
      end)

    case Enum.find_index(ai_players, &(&1 == player_id)) do
      nil -> 1
      idx -> idx + 1
    end
  end

  # Get skip message based on AI character
  defp get_skip_message(ai_index, reason) do
    character =
      case ai_index do
        1 -> %{name: "森の精霊ミドリ", emoji: "🌳"}
        2 -> %{name: "文化の守人カグラ", emoji: "🎎"}
        3 -> %{name: "絆の使者ムスビ", emoji: "🤝"}
        4 -> %{name: "空環の賢者アカシャ", emoji: "✨"}
        _ -> %{name: "AI", emoji: "🤖"}
      end

    message =
      case {ai_index, reason} do
        {1, :no_affordable_cards} ->
          "空環が足りないの…今年は見守ることしかできないわ。"

        {1, :no_cards} ->
          "手札がないの…次の年に備えるわね。"

        {2, :no_affordable_cards} ->
          "空環が不足しております。今年は力を蓄える年となりましょう。"

        {2, :no_cards} ->
          "手持ちのカードがございません。来年に期待いたします。"

        {3, :no_affordable_cards} ->
          "ごめん、空環が足りなくて何もできないや…。"

        {3, :no_cards} ->
          "手札がないんだ。次の年、頑張るね！"

        {4, :no_affordable_cards} ->
          "空環が足りぬ。時には待つことも知恵であろう。"

        {4, :no_cards} ->
          "手札がない。次の機会を待つとしよう。"

        _ ->
          "今年は行動できません。"
      end

    "#{character.emoji} #{character.name}: #{message}"
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
