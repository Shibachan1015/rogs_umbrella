defmodule Shinkanki.Games do
  @moduledoc """
  ゲームセッション管理のコンテキスト
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo

  alias Shinkanki.Games.{
    GameSession,
    Player,
    ActionCard,
    EventCard,
    TurnState,
    GameProject,
    ProjectTemplate,
    GameAction,
    ProjectParticipation
  }

  # ===================
  # ゲームセッション管理
  # ===================

  @doc """
  新しいゲームセッションを作成
  ランダムな初期値を設定（F/K/S: 8〜12）
  """
  def create_game_session(attrs \\ %{}) do
    initial_values = %{
      forest: Enum.random(8..12),
      culture: Enum.random(8..12),
      social: Enum.random(8..12),
      turn: 1,
      dao_pool: 0,
      status: "active",
      seed: generate_seed()
    }

    life_index = initial_values.forest + initial_values.culture + initial_values.social
    attrs = Map.merge(initial_values, Map.put(attrs, :life_index, life_index))

    %GameSession{}
    |> GameSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  ゲームセッションを取得（関連データをpreload）
  """
  def get_game_session!(id) do
    GameSession
    |> Repo.get!(id)
    |> Repo.preload([
      :players,
      :turn_states,
      :game_actions,
      game_projects: [:project_template, :project_participations]
    ])
  end

  @doc """
  ゲームセッションのパラメータを更新
  """
  def update_game_session(%GameSession{} = game_session, attrs) do
    game_session
    |> GameSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  生命指数を再計算して更新
  L = F + K + S
  """
  def update_life_index(%GameSession{} = game_session) do
    life_index = game_session.forest + game_session.culture + game_session.social

    game_session
    |> GameSession.changeset(%{life_index: life_index})
    |> Repo.update()
  end

  # ===================
  # プレイヤー管理
  # ===================

  @doc """
  4人のプレイヤーを作成
  役割: forest_guardian, heritage_weaver, community_keeper, akasha_architect
  初期Akasha: 800〜1200（ランダム）
  """
  def create_players(game_session_id) do
    roles = ["forest_guardian", "heritage_weaver", "community_keeper", "akasha_architect"]

    Enum.map(1..4, fn order ->
      player_attrs = %{
        game_session_id: game_session_id,
        akasha: Enum.random(800..1200),
        role: Enum.at(roles, order - 1),
        player_order: order
      }

      %Player{}
      |> Player.changeset(player_attrs)
      |> Repo.insert()
    end)
  end

  @doc """
  プレイヤーを取得
  """
  def get_player!(id) do
    Player
    |> Repo.get!(id)
    |> Repo.preload([:game_session, :game_actions, :project_participations])
  end

  @doc """
  プレイヤーのAkashaを更新
  """
  def update_player_akasha(%Player{} = player, amount) do
    new_akasha = max(0, player.akasha + amount)

    player
    |> Player.changeset(%{akasha: new_akasha})
    |> Repo.update()
  end

  @doc """
  全プレイヤーにAkasha減衰を適用（10%）
  減衰分は地域DAOプールへ
  """
  def apply_demurrage_to_all(game_session_id) do
    game_session = get_game_session!(game_session_id)

    total_demurrage =
      Enum.reduce(game_session.players, 0, fn player, acc ->
        demurrage_amount = div(player.akasha, 10)
        new_akasha = player.akasha - demurrage_amount

        player
        |> Player.changeset(%{akasha: new_akasha})
        |> Repo.update!()

        acc + demurrage_amount
      end)

    # DAOプールに追加
    add_to_dao_pool(game_session, total_demurrage)
  end

  # ===================
  # ターン管理
  # ===================

  @doc """
  新しいターンを開始
  - イベントカードをドロー
  - 場にアクションカード5枚を並べる
  - TurnStateを作成
  """
  def start_new_turn(%GameSession{} = game_session) do
    event_card = draw_event_card()
    action_cards = draw_action_cards(5)
    action_card_ids = Enum.map(action_cards, & &1.id)

    turn_state_attrs = %{
      game_session_id: game_session.id,
      turn_number: game_session.turn,
      phase: "event",
      available_cards: action_card_ids,
      current_event_id: if(event_card, do: event_card.id, else: nil)
    }

    %TurnState{}
    |> TurnState.changeset(turn_state_attrs)
    |> Repo.insert()
  end

  @doc """
  ターンのフェーズを進める
  event -> action -> dao -> end
  """
  def advance_phase(%TurnState{} = turn_state) do
    next_phase = TurnState.next_phase(turn_state.phase)

    turn_state
    |> TurnState.changeset(%{phase: next_phase})
    |> Repo.update()
  end

  @doc """
  ターンを終了して次のターンへ
  - 減衰処理
  - 生命指数更新
  - 敗北チェック
  - ターン数+1
  """
  def end_turn(%GameSession{} = game_session) do
    # 減衰処理
    {:ok, updated_session} = apply_demurrage_to_all(game_session.id)

    # 生命指数更新
    {:ok, updated_session} = update_life_index(updated_session)

    # 敗北チェック
    case check_game_end(updated_session) do
      {:immediate_loss, reason} ->
        update_game_session(updated_session, %{status: "failed"})
        {:game_over, reason}

      {:completed, ending} ->
        update_game_session(updated_session, %{status: "completed"})
        {:game_over, ending}

      {:continue, _} ->
        # ターン数+1
        update_game_session(updated_session, %{turn: updated_session.turn + 1})
    end
  end

  # ===================
  # カード管理
  # ===================

  @doc """
  ランダムにアクションカードを選ぶ
  """
  def draw_action_cards(count \\ 5) do
    ActionCard
    |> order_by(fragment("RANDOM()"))
    |> limit(^count)
    |> Repo.all()
  end

  @doc """
  ランダムにイベントカードを1枚選ぶ
  """
  def draw_event_card do
    EventCard
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  アクションカードを実行
  - コストチェック
  - 効果適用（役割ボーナス含む）
  - アクション履歴記録
  """
  def execute_action_card(%Player{} = player, %ActionCard{} = card, %GameSession{} = game_session) do
    # コストチェック
    if ActionCard.check_costs(card, game_session, player) do
      # 役割ボーナス計算
      role_bonus = Player.role_bonus(player.role, card.category)

      # 効果適用
      new_forest =
        clamp(
          game_session.forest + card.effect_forest +
            role_bonus_for(:forest, card.category, role_bonus),
          0,
          20
        )

      new_culture =
        clamp(
          game_session.culture + card.effect_culture +
            role_bonus_for(:culture, card.category, role_bonus),
          0,
          20
        )

      new_social =
        clamp(
          game_session.social + card.effect_social +
            role_bonus_for(:social, card.category, role_bonus),
          0,
          20
        )

      # プレイヤーのAkasha更新
      {:ok, _updated_player} = update_player_akasha(player, -card.cost_akasha)

      # ゲームセッション更新
      {:ok, updated_session} =
        update_game_session(game_session, %{
          forest: new_forest - card.cost_forest,
          culture: new_culture - card.cost_culture,
          social: new_social - card.cost_social
        })

      # アクション履歴記録
      record_action(game_session, player, card, "play_card")

      {:ok, updated_session}
    else
      {:error, :insufficient_resources}
    end
  end

  defp role_bonus_for(category, card_category, bonus) do
    if Atom.to_string(category) == card_category, do: bonus, else: 0
  end

  @doc """
  イベントカードの効果を適用
  選択肢がある場合はchoiceを指定（:choice_a or :choice_b）
  """
  def apply_event_card(%EventCard{} = event, %GameSession{} = game_session, choice \\ nil) do
    effects =
      if event.has_choice and choice do
        EventCard.get_effects(event, choice)
      else
        EventCard.get_effects(event)
      end

    new_forest = clamp(game_session.forest + Map.get(effects, :forest, 0), 0, 20)
    new_culture = clamp(game_session.culture + Map.get(effects, :culture, 0), 0, 20)
    new_social = clamp(game_session.social + Map.get(effects, :social, 0), 0, 20)

    update_game_session(game_session, %{
      forest: new_forest,
      culture: new_culture,
      social: new_social
    })
  end

  # ===================
  # 共創プロジェクト管理
  # ===================

  @doc """
  ゲーム開始時にプロジェクトを2〜3個配置
  """
  def setup_initial_projects(%GameSession{} = game_session) do
    count = Enum.random(2..3)

    templates =
      ProjectTemplate
      |> order_by(fragment("RANDOM()"))
      |> limit(^count)
      |> Repo.all()

    Enum.map(templates, fn template ->
      %GameProject{}
      |> GameProject.changeset(%{
        game_session_id: game_session.id,
        project_template_id: template.id,
        started_turn: game_session.turn,
        status: "active"
      })
      |> Repo.insert()
    end)
  end

  @doc """
  プレイヤーがプロジェクトに参加
  """
  def join_project(%Player{} = player, %GameProject{} = project, turn) do
    %ProjectParticipation{}
    |> ProjectParticipation.changeset(%{
      game_project_id: project.id,
      player_id: player.id,
      turn: turn
    })
    |> Repo.insert()
  end

  @doc """
  プロジェクトの完成をチェックし、完成していれば効果を適用
  """
  def check_and_complete_projects(%GameSession{} = game_session) do
    game_session =
      Repo.preload(game_session, game_projects: [:project_template, :project_participations])

    Enum.reduce(game_session.game_projects, game_session, fn project, acc_session ->
      if GameProject.active?(project) do
        template = project.project_template
        participant_count = GameProject.participant_count(project)

        # 完成条件チェック
        participants_met = participant_count >= template.required_participants

        turns_met =
          if template.required_turns do
            acc_session.turn - project.started_turn >= template.required_turns
          else
            true
          end

        dao_pool_met =
          if template.required_dao_pool do
            acc_session.dao_pool >= template.required_dao_pool
          else
            true
          end

        if participants_met and turns_met and dao_pool_met do
          # プロジェクト完成
          complete_project(project, acc_session)
        else
          acc_session
        end
      else
        acc_session
      end
    end)
  end

  defp complete_project(%GameProject{} = project, %GameSession{} = game_session) do
    template = project.project_template

    # 効果適用
    new_forest = clamp(game_session.forest + template.effect_forest, 0, 20)
    new_culture = clamp(game_session.culture + template.effect_culture, 0, 20)
    new_social = clamp(game_session.social + template.effect_social, 0, 20)

    # プロジェクトを完成状態に
    project
    |> GameProject.changeset(%{status: "completed", completed_turn: game_session.turn})
    |> Repo.update!()

    # ゲームセッション更新
    {:ok, updated_session} =
      update_game_session(game_session, %{
        forest: new_forest,
        culture: new_culture,
        social: new_social
      })

    # Akasha効果があればプレイヤーに配布
    if template.effect_akasha > 0 do
      distribute_akasha_to_participants(project, template.effect_akasha)
    end

    updated_session
  end

  defp distribute_akasha_to_participants(%GameProject{} = project, amount) do
    project = Repo.preload(project, :project_participations)

    player_ids =
      project.project_participations
      |> Enum.map(& &1.player_id)
      |> Enum.uniq()

    per_player = div(amount, max(length(player_ids), 1))

    Enum.each(player_ids, fn player_id ->
      player = Repo.get!(Player, player_id)
      update_player_akasha(player, per_player)
    end)
  end

  # ===================
  # 地域DAO管理
  # ===================

  @doc """
  地域DAOプールにAkashaを追加
  """
  def add_to_dao_pool(%GameSession{} = game_session, amount) do
    new_dao_pool = game_session.dao_pool + amount
    update_game_session(game_session, %{dao_pool: new_dao_pool})
  end

  @doc """
  地域DAOの投票アクションを実行
  action_type: :invest_forest | :invest_culture | :invest_social | :distribute | :mitigate_event
  """
  def execute_dao_action(%GameSession{} = game_session, action_type) do
    case action_type do
      :invest_forest ->
        cost = min(game_session.dao_pool, 100)
        effect = div(cost, 50)
        new_forest = clamp(game_session.forest + effect, 0, 20)

        update_game_session(game_session, %{
          forest: new_forest,
          dao_pool: game_session.dao_pool - cost
        })

      :invest_culture ->
        cost = min(game_session.dao_pool, 100)
        effect = div(cost, 50)
        new_culture = clamp(game_session.culture + effect, 0, 20)

        update_game_session(game_session, %{
          culture: new_culture,
          dao_pool: game_session.dao_pool - cost
        })

      :invest_social ->
        cost = min(game_session.dao_pool, 100)
        effect = div(cost, 50)
        new_social = clamp(game_session.social + effect, 0, 20)

        update_game_session(game_session, %{
          social: new_social,
          dao_pool: game_session.dao_pool - cost
        })

      :distribute ->
        distribute_dao_pool(game_session)

      :mitigate_event ->
        # イベント軽減（DAOプールの半分を使用）
        cost = div(game_session.dao_pool, 2)
        update_game_session(game_session, %{dao_pool: game_session.dao_pool - cost})

      _ ->
        {:error, :unknown_action}
    end
  end

  defp distribute_dao_pool(%GameSession{} = game_session) do
    game_session = Repo.preload(game_session, :players)
    player_count = length(game_session.players)

    if player_count > 0 do
      per_player = div(game_session.dao_pool, player_count)

      Enum.each(game_session.players, fn player ->
        update_player_akasha(player, per_player)
      end)

      update_game_session(game_session, %{dao_pool: rem(game_session.dao_pool, player_count)})
    else
      {:ok, game_session}
    end
  end

  # ===================
  # 勝敗判定
  # ===================

  @doc """
  即時敗北条件をチェック
  F=0, K=0, S=0 のいずれかで敗北
  """
  def check_immediate_loss(%GameSession{} = game_session) do
    GameSession.check_immediate_loss?(game_session)
  end

  @doc """
  ゲーム終了判定
  返り値: {:continue, nil} | {:immediate_loss, reason} | {:completed, ending}
  """
  def check_game_end(%GameSession{} = game_session) do
    cond do
      check_immediate_loss(game_session) -> {:immediate_loss, get_loss_reason(game_session)}
      game_session.turn >= 20 -> {:completed, get_ending(game_session)}
      true -> {:continue, nil}
    end
  end

  @doc """
  エンディングを取得
  L>=40: :gods_blessing
  30-39: :purification
  20-29: :fluctuation
  <=19: :gods_lament
  """
  def get_ending(%GameSession{} = game_session) do
    GameSession.get_ending(game_session)
  end

  # ===================
  # ヘルパー関数
  # ===================

  defp get_loss_reason(%GameSession{forest: 0}), do: :forest_lost
  defp get_loss_reason(%GameSession{culture: 0}), do: :culture_lost
  defp get_loss_reason(%GameSession{social: 0}), do: :social_lost
  defp get_loss_reason(_), do: :unknown

  defp generate_seed do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end

  defp record_action(
         %GameSession{} = game_session,
         %Player{} = player,
         %ActionCard{} = card,
         action_type
       ) do
    %GameAction{}
    |> GameAction.changeset(%{
      game_session_id: game_session.id,
      player_id: player.id,
      action_card_id: card.id,
      turn: game_session.turn,
      action_type: action_type,
      details: %{}
    })
    |> Repo.insert()
  end
end
