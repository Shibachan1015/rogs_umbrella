defmodule Shinkanki.GamePubSub do
  @moduledoc """
  ゲームイベントのブロードキャスト
  リアルタイム同期のためのPubSubインターフェース
  """

  @pubsub Shinkanki.PubSub

  @doc """
  ゲームセッションのトピックを購読
  """
  def subscribe(game_session_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(game_session_id))
  end

  @doc """
  ゲームセッションのトピックから購読解除
  """
  def unsubscribe(game_session_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(game_session_id))
  end

  @doc """
  ゲーム状態の更新をブロードキャスト
  """
  def broadcast_state_update(game_session_id, state) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:game_state_updated, state}
    )
  end

  @doc """
  プレイヤーアクションをブロードキャスト
  """
  def broadcast_player_action(game_session_id, player_id, action) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:player_action, %{player_id: player_id, action: action}}
    )
  end

  @doc """
  チャットメッセージをブロードキャスト
  """
  def broadcast_chat(game_session_id, player_id, message) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:chat_message, %{player_id: player_id, message: message, timestamp: DateTime.utc_now()}}
    )
  end

  @doc """
  ターン開始をブロードキャスト
  """
  def broadcast_turn_start(game_session_id, turn_number, event_card) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:turn_started, %{turn: turn_number, event_card: event_card}}
    )
  end

  @doc """
  フェーズ変更をブロードキャスト
  """
  def broadcast_phase_change(game_session_id, new_phase) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:phase_changed, %{phase: new_phase}}
    )
  end

  @doc """
  プロジェクト完成をブロードキャスト
  """
  def broadcast_project_completed(game_session_id, project) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:project_completed, project}
    )
  end

  @doc """
  ゲーム終了をブロードキャスト
  """
  def broadcast_game_end(game_session_id, result) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:game_ended, result}
    )
  end

  @doc """
  プレイヤー参加をブロードキャスト
  """
  def broadcast_player_joined(game_session_id, player) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:player_joined, player}
    )
  end

  @doc """
  プレイヤー退出をブロードキャスト
  """
  def broadcast_player_left(game_session_id, player_id) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(game_session_id),
      {:player_left, player_id}
    )
  end

  # プライベート関数

  defp topic(game_session_id) do
    "game:#{game_session_id}"
  end
end
