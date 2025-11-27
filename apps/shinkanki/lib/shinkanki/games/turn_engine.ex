defmodule Shinkanki.Games.TurnEngine do
  @moduledoc """
  ターン進行ロジック
  """

  alias Shinkanki.Repo
  alias Shinkanki.Games
  alias Shinkanki.Games.{GameSession, TurnState, Player, GameAction}
  import Ecto.Query

  @phases ["event", "action", "dao", "end"]

  @doc """
  1ターンの完全なフローを実行
  1. イベントフェーズ
  2. アクションフェーズ（プレイヤーの入力待ち）
  3. DAOフェーズ
  4. 終了フェーズ（減衰、更新）
  """
  def process_turn(%GameSession{} = game_session) do
    game_session = Repo.preload(game_session, [:players, :turn_states])

    # 現在のターン状態を取得または作成
    turn_state = get_or_create_turn_state(game_session)

    case turn_state.phase do
      "event" ->
        process_event_phase(game_session, turn_state)

      "action" ->
        # アクションフェーズはプレイヤーの入力待ち
        {:waiting_for_actions, turn_state}

      "dao" ->
        process_dao_phase(game_session, turn_state)

      "end" ->
        process_end_phase(game_session, turn_state)

      _ ->
        {:error, :unknown_phase}
    end
  end

  @doc """
  フェーズを次へ進める
  """
  def next_phase(%TurnState{} = turn_state) do
    current_index = Enum.find_index(@phases, &(&1 == turn_state.phase))

    if current_index do
      next_index = rem(current_index + 1, length(@phases))
      next_phase_name = Enum.at(@phases, next_index)

      turn_state
      |> TurnState.changeset(%{phase: next_phase_name})
      |> Repo.update()
    else
      {:error, :invalid_phase}
    end
  end

  @doc """
  全プレイヤーがアクションを完了したかチェック
  """
  def all_players_acted?(%GameSession{} = game_session, turn) do
    game_session = Repo.preload(game_session, :players)
    player_count = length(game_session.players)

    action_count =
      GameAction
      |> where([a], a.game_session_id == ^game_session.id and a.turn == ^turn)
      |> Repo.aggregate(:count)

    action_count >= player_count
  end

  @doc """
  現在のターン状態を取得
  """
  def get_current_turn_state(%GameSession{} = game_session) do
    TurnState
    |> where([t], t.game_session_id == ^game_session.id and t.turn_number == ^game_session.turn)
    |> Repo.one()
  end

  @doc """
  フェーズ名を日本語で取得
  """
  def phase_name("event"), do: "イベントフェーズ"
  def phase_name("action"), do: "アクションフェーズ"
  def phase_name("dao"), do: "DAOフェーズ"
  def phase_name("end"), do: "終了フェーズ"
  def phase_name(_), do: "不明"

  # プライベート関数

  defp get_or_create_turn_state(%GameSession{} = game_session) do
    case get_current_turn_state(game_session) do
      nil ->
        {:ok, turn_state} = Games.start_new_turn(game_session)
        turn_state

      turn_state ->
        turn_state
    end
  end

  defp process_event_phase(%GameSession{} = game_session, %TurnState{} = turn_state) do
    # イベントカードの効果を適用
    if turn_state.current_event_id do
      event = Repo.get!(Shinkanki.Games.EventCard, turn_state.current_event_id)
      {:ok, updated_session} = Games.apply_event_card(event, game_session)

      # 次のフェーズへ
      {:ok, updated_turn_state} = next_phase(turn_state)

      {:ok, %{game_session: updated_session, turn_state: updated_turn_state, phase: "action"}}
    else
      # イベントカードがない場合はスキップ
      {:ok, updated_turn_state} = next_phase(turn_state)
      {:ok, %{game_session: game_session, turn_state: updated_turn_state, phase: "action"}}
    end
  end

  defp process_dao_phase(%GameSession{} = game_session, %TurnState{} = turn_state) do
    # DAOフェーズの処理（自動的に何もしないか、デフォルトアクションを実行）
    # 実際のゲームではプレイヤーの投票を待つ

    # 次のフェーズへ
    {:ok, updated_turn_state} = next_phase(turn_state)

    {:ok, %{game_session: game_session, turn_state: updated_turn_state, phase: "end"}}
  end

  defp process_end_phase(%GameSession{} = game_session, %TurnState{} = _turn_state) do
    # 終了フェーズ処理
    case Games.end_turn(game_session) do
      {:ok, updated_session} ->
        # 次のターンを開始
        {:ok, new_turn_state} = Games.start_new_turn(updated_session)
        {:ok, %{game_session: updated_session, turn_state: new_turn_state, phase: "event", new_turn: true}}

      {:game_over, reason} ->
        {:game_over, reason}

      error ->
        error
    end
  end

  @doc """
  アクションフェーズでプレイヤーのアクションを処理
  """
  def process_player_action(%GameSession{} = game_session, %Player{} = player, action_card_id) do
    turn_state = get_current_turn_state(game_session)

    if turn_state && turn_state.phase == "action" do
      # アクションカードが場にあるかチェック
      if action_card_id in turn_state.available_cards do
        action_card = Repo.get!(Shinkanki.Games.ActionCard, action_card_id)

        case Games.execute_action_card(player, action_card, game_session) do
          {:ok, updated_session} ->
            # 全員がアクションしたかチェック
            if all_players_acted?(updated_session, game_session.turn) do
              {:ok, updated_turn_state} = next_phase(turn_state)
              {:ok, %{game_session: updated_session, turn_state: updated_turn_state, all_acted: true}}
            else
              {:ok, %{game_session: updated_session, turn_state: turn_state, all_acted: false}}
            end

          error ->
            error
        end
      else
        {:error, :card_not_available}
      end
    else
      {:error, :not_action_phase}
    end
  end

  @doc """
  プロジェクトへの参加を処理
  """
  def process_project_participation(%GameSession{} = game_session, %Player{} = player, project_id) do
    game_session = Repo.preload(game_session, :game_projects)

    project = Enum.find(game_session.game_projects, &(&1.id == project_id))

    if project && Shinkanki.Games.GameProject.active?(project) do
      case Games.join_project(player, project, game_session.turn) do
        {:ok, _participation} ->
          # プロジェクト完成チェック
          updated_session = Games.check_and_complete_projects(game_session)
          {:ok, updated_session}

        error ->
          error
      end
    else
      {:error, :project_not_found_or_inactive}
    end
  end
end
