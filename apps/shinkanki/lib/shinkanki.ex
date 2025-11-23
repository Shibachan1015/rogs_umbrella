defmodule Shinkanki do
  @moduledoc """
  Shinkanki keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  import Ecto.Query
  alias Shinkanki.{GameServer, Game, ActionLog, Repo}

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
  Advances the game to the next phase.
  """
  def next_phase(room_id) do
    call_server(room_id, fn -> GameServer.next_phase(room_id) end)
  end

  @doc """
  Updates the game statistics manually.
  """
  def update_stats(room_id, changes) do
    call_server(room_id, fn -> GameServer.update_stats(room_id, changes) end)
  end

  @doc """
  Lets a player join the room with optional talents.
  """
  def join_player(room_id, player_id, name, talent_ids \\ nil) do
    call_server(room_id, fn -> GameServer.join_player(room_id, player_id, name, talent_ids) end)
  end

  @doc """
  Plays a card in the given room.
  """
  def play_card(room_id, card_id) do
    call_server(room_id, fn -> GameServer.play_card(room_id, card_id) end)
  end

  @doc """
  Plays an action card with optional talents for the given player.
  """
  def play_action(room_id, player_id, action_id, talent_ids \\ []) do
    call_server(room_id, fn ->
      GameServer.play_action(room_id, player_id, action_id, talent_ids)
    end)
  end

  @doc """
  Subscribes the current process to game updates for the given room_id.
  """
  def subscribe_game(room_id) do
    Phoenix.PubSub.subscribe(Shinkanki.PubSub, "shinkanki:game:#{room_id}")
  end

  @doc """
  Executes an AI player's turn automatically.
  Returns {:ok, new_game} or {:error, reason}.
  """
  def ai_turn(room_id, player_id) do
    call_server(room_id, fn ->
      GameServer.ai_turn(room_id, player_id)
    end)
  end

  @doc """
  Contributes a talent card to a project to advance its progress.
  Returns {:ok, new_game} or {:error, reason}.
  """
  def contribute_talent_to_project(room_id, player_id, project_id, talent_id) do
    call_server(room_id, fn ->
      GameServer.contribute_talent_to_project(room_id, player_id, project_id, talent_id)
    end)
  end

  @doc """
  Replays a game from action logs.
  Returns the final game state after replaying all actions.
  """
  def replay_game(room_id) do
    if Code.ensure_loaded?(Repo) and function_exported?(Repo, :all, 1) do
      logs =
        Repo.all(
          from log in ActionLog,
            where: log.room_id == ^room_id,
            order_by: [asc: log.inserted_at]
        )

      initial_game = Game.new(room_id)

      Enum.reduce(logs, initial_game, fn log, game ->
        apply_action_log(game, log)
      end)
    else
      {:error, :repo_not_available}
    end
  end

  defp apply_action_log(game, %ActionLog{
         action: "join_player",
         player_id: player_id,
         payload: payload
       }) do
    case Game.join(
           game,
           player_id,
           payload["name"] || payload[:name],
           payload["talent_ids"] || payload[:talent_ids]
         ) do
      {:ok, new_game} -> new_game
      _ -> game
    end
  end

  defp apply_action_log(game, %ActionLog{
         action: "play_action",
         player_id: player_id,
         payload: payload
       }) do
    action_id = payload["action_id"] || payload[:action_id]
    talent_ids = payload["talent_ids"] || payload[:talent_ids] || []

    case Game.play_action(game, player_id, action_id, talent_ids) do
      {:ok, new_game} -> new_game
      _ -> game
    end
  end

  defp apply_action_log(game, %ActionLog{action: "play_card", payload: payload}) do
    card_id = payload["card_id"] || payload[:card_id]

    case Game.play_card(game, card_id) do
      {:ok, new_game} -> new_game
      _ -> game
    end
  end

  defp apply_action_log(game, %ActionLog{action: "next_turn"}) do
    Game.next_turn(game)
  end

  defp apply_action_log(game, %ActionLog{action: "update_stats", payload: payload}) do
    changes = payload["changes"] || payload[:changes] || %{}
    Game.update_stats(game, changes)
  end

  defp apply_action_log(game, _log), do: game

  defp call_server(room_id, fun) do
    case Registry.lookup(Shinkanki.GameRegistry, room_id) do
      [{_pid, _}] -> fun.()
      [] -> {:error, :game_not_found}
    end
  end
end
