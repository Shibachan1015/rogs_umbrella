defmodule Shinkanki.Games do
  @moduledoc """
  ゲームセッション管理のコンテキスト
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo
  alias Shinkanki.GamePubSub

  alias Shinkanki.Games.{
    GameSession,
    Player,
    ActionCard,
    EventCard,
    TurnState,
    GameProject,
    ProjectTemplate,
    GameAction,
    ProjectParticipation,
    TalentCard,
    PlayerTalent
  }

  # ===================
  # ゲームセッション管理
  # ===================

  @doc """
  新しいゲームセッションを作成
  ランダムな初期値を設定（F/K/S: 3〜5、絶望的な状態からスタート）
  """
  def create_game_session(attrs \\ %{}) do
    initial_values = %{
      forest: Enum.random(3..5),
      culture: Enum.random(3..5),
      social: Enum.random(3..5),
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
  ルームIDとユーザーIDリストからゲームセッションを作成し、プレイヤーも作成
  """
  def create_game_session_from_room(room_id, user_ids) do
    Repo.transaction(fn ->
      # ゲームセッションを作成（room_idを含める）
      {:ok, game_session} = create_game_session(%{room_id: room_id})

      # プレイヤーを作成
      _players = create_players(game_session.id, user_ids)

      # 初期プロジェクトをセットアップ
      setup_initial_projects(game_session)

      # 最初のターンを開始
      {:ok, _turn_state} = start_new_turn(game_session)

      # ゲームセッションを再取得（関連データをpreload）
      get_game_session!(game_session.id)
    end)
  end

  @doc """
  ルームIDからゲームセッションを取得
  """
  def get_game_session_by_room_id(room_id) do
    GameSession
    |> where([gs], gs.room_id == ^room_id)
    |> order_by([gs], desc: gs.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      game_session -> get_game_session!(game_session.id)
    end
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
  プレイヤーを作成
  user_ids: ユーザーIDのリスト（最大4人）
  役割: forest_guardian, heritage_weaver, community_keeper, akasha_architect
  初期Akasha: 50〜100（少なめ）
  """
  def create_players(game_session_id, user_ids \\ []) do
    roles = ["forest_guardian", "heritage_weaver", "community_keeper", "akasha_architect"]

    Enum.with_index(user_ids, 1)
    |> Enum.map(fn {user_id, index} ->
      player_attrs = %{
        game_session_id: game_session_id,
        user_id: user_id,
        akasha: Enum.random(50..100),
        role: Enum.at(roles, index - 1),
        player_order: index,
        is_ai: false
      }

      {:ok, player} =
        %Player{}
        |> Player.changeset(player_attrs)
        |> Repo.insert()

      # プレイヤーにタレントカードを割り当て（役割に応じて2枚）
      assign_talents_to_player(player)

      {:ok, player}
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

  @doc """
  AIプレイヤーで4人になるように補完
  現在の人間プレイヤー数を確認し、足りない分をAIで埋める
  """
  def fill_with_ai_players(game_session_id, human_players) do
    human_count = length(human_players)
    roles = ["forest_guardian", "heritage_weaver", "community_keeper", "akasha_architect"]

    # 人間プレイヤーが使用している役割を取得
    used_roles = Enum.map(human_players, fn p -> p.role end)
    available_roles = Enum.reject(roles, &(&1 in used_roles))

    # 足りない分のAIプレイヤーを作成
    ai_count = 4 - human_count

    if ai_count > 0 do
      1..ai_count
      |> Enum.map(fn idx ->
        # player_orderは1から始まるので、human_count + idx（例: 人間1人 + AI1番目 = 2）
        player_order = human_count + idx
        role = Enum.at(available_roles, idx - 1, Enum.at(roles, player_order - 1))

        ai_attrs = Player.ai_player_attrs(player_order, role)
        attrs = Map.put(ai_attrs, :game_session_id, game_session_id)

        %Player{}
        |> Player.changeset(attrs)
        |> Repo.insert!()
      end)
    else
      []
    end
  end

  @doc """
  ゲームセッションのAIプレイヤーを取得
  """
  def get_ai_players(game_session_id) do
    from(p in Player,
      where: p.game_session_id == ^game_session_id and p.is_ai == true
    )
    |> Repo.all()
  end

  @doc """
  プレイヤーがAIかどうかを確認
  """
  def ai_player?(%Player{is_ai: is_ai}), do: is_ai

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

  # game_session_idからターンのフェーズを進める
  def advance_phase(game_session_id) when is_binary(game_session_id) do
    game_session = get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)

    if turn_state do
      advance_phase(turn_state)
    else
      {:error, :no_turn_state}
    end
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
  - 邪気デルタ適用
  - 方針違反チェック
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

      # カードの邪気デルタを適用（evil_deltaフィールドがある場合）
      evil_delta = Map.get(card, :evil_delta, 0) || 0
      {:ok, updated_session} = if evil_delta != 0 do
        add_evil(updated_session, evil_delta)
      else
        {:ok, updated_session}
      end

      # 方針違反チェック（方針と異なるカテゴリのカードを使用した場合）
      {:ok, updated_session} = if check_policy_violation(game_session, card.category) do
        # 方針違反: プレイヤーに邪気+1
        add_player_evil(updated_session, player.id, 1)
      else
        {:ok, updated_session}
      end

      # 生命指数を更新
      {:ok, updated_session} = update_life_index(updated_session)

      # アクション履歴記録
      record_action(updated_session, player, card, "play_card")

      # ゲーム終了チェック
      case check_game_end(updated_session) do
        {:immediate_loss, reason} ->
          {:ok, final_session} = update_game_session(updated_session, %{status: "failed"})
          GamePubSub.broadcast_game_end(final_session.id, reason)
          {:ok, final_session}

        {:completed, ending} ->
          {:ok, final_session} = update_game_session(updated_session, %{status: "completed"})
          GamePubSub.broadcast_game_end(final_session.id, ending)
          {:ok, final_session}

        {:continue, _} ->
          # 状態更新をブロードキャスト
          GamePubSub.broadcast_state_update(updated_session.id, updated_session)
          {:ok, updated_session}
      end
    else
      {:error, :insufficient_resources}
    end
  end

  @doc """
  タレント付きでアクションカードを実行
  talent_ids: 使用するタレントのPlayerTalent IDリスト（最大2枚）
  """
  def execute_action_card_with_talents(
        %Player{} = player,
        %ActionCard{} = card,
        %GameSession{} = game_session,
        talent_ids \\ []
      ) do
    # タレントを取得
    talents =
      talent_ids
      |> Enum.take(2)
      |> Enum.map(fn id ->
        pt = Repo.get!(PlayerTalent, id) |> Repo.preload(:talent_card)
        pt.talent_card
      end)

    # コスト削減を計算
    base_costs = %{
      akasha: card.cost_akasha,
      forest: card.cost_forest,
      culture: card.cost_culture,
      social: card.cost_social
    }

    final_costs =
      Enum.reduce(talents, base_costs, fn talent, acc ->
        if talent.effect_type == "cost_reduction" do
          TalentCard.apply_effect(talent, acc, card.category)
        else
          acc
        end
      end)

    # コストチェック（削減後のコストで）
    can_afford =
      player.akasha >= final_costs.akasha and
        game_session.forest >= final_costs.forest and
        game_session.culture >= final_costs.culture and
        game_session.social >= final_costs.social

    if can_afford do
      # 役割ボーナス計算
      role_bonus = Player.role_bonus(player.role, card.category)

      # 基本効果
      base_effects = %{
        forest: card.effect_forest + role_bonus_for(:forest, card.category, role_bonus),
        culture: card.effect_culture + role_bonus_for(:culture, card.category, role_bonus),
        social: card.effect_social + role_bonus_for(:social, card.category, role_bonus)
      }

      # タレント効果を適用（bonus系）
      final_effects =
        Enum.reduce(talents, base_effects, fn talent, acc ->
          if talent.effect_type != "cost_reduction" do
            TalentCard.apply_effect(talent, acc, card.category)
          else
            acc
          end
        end)

      # 効果適用
      new_forest = clamp(game_session.forest + final_effects.forest - final_costs.forest, 0, 20)
      new_culture = clamp(game_session.culture + final_effects.culture - final_costs.culture, 0, 20)
      new_social = clamp(game_session.social + final_effects.social - final_costs.social, 0, 20)

      # プレイヤーのAkasha更新
      {:ok, _updated_player} = update_player_akasha(player, -final_costs.akasha)

      # タレントを使用済みにする
      Enum.each(talent_ids, fn id ->
        use_talent_by_id(id)
      end)

      # ゲームセッション更新
      {:ok, updated_session} =
        update_game_session(game_session, %{
          forest: new_forest,
          culture: new_culture,
          social: new_social
        })

      # カードの邪気デルタを適用（evil_deltaフィールドがある場合）
      evil_delta = Map.get(card, :evil_delta, 0) || 0
      {:ok, updated_session} = if evil_delta != 0 do
        add_evil(updated_session, evil_delta)
      else
        {:ok, updated_session}
      end

      # 方針違反チェック（方針と異なるカテゴリのカードを使用した場合）
      {:ok, updated_session} = if check_policy_violation(game_session, card.category) do
        # 方針違反: プレイヤーに邪気+1
        add_player_evil(updated_session, player.id, 1)
      else
        {:ok, updated_session}
      end

      # 生命指数を更新
      {:ok, updated_session} = update_life_index(updated_session)

      # アクション履歴記録
      record_action(updated_session, player, card, "play_card_with_talents")

      # ゲーム終了チェック
      case check_game_end(updated_session) do
        {:immediate_loss, reason} ->
          {:ok, final_session} = update_game_session(updated_session, %{status: "failed"})
          GamePubSub.broadcast_game_end(final_session.id, reason)
          {:ok, final_session}

        {:completed, ending} ->
          {:ok, final_session} = update_game_session(updated_session, %{status: "completed"})
          GamePubSub.broadcast_game_end(final_session.id, ending)
          {:ok, final_session}

        {:continue, _} ->
          # 状態更新をブロードキャスト
          GamePubSub.broadcast_state_update(updated_session.id, updated_session)
          {:ok, updated_session}
      end
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

  # ===================
  # タレントカード管理
  # ===================

  @doc """
  役割に応じたタレントカードを取得
  """
  def get_talents_for_role(role) do
    category = role_to_category(role)

    TalentCard
    |> where([t], t.category == ^category)
    |> Repo.all()
  end

  @doc """
  全てのタレントカードを取得
  """
  def list_talent_cards do
    Repo.all(TalentCard)
  end

  @doc """
  タレントカードを取得
  """
  def get_talent_card!(id) do
    Repo.get!(TalentCard, id)
  end

  @doc """
  プレイヤーにタレントを割り当て
  各プレイヤーは役割に応じたタレントから2枚をランダムに取得
  """
  def assign_talents_to_player(%Player{} = player) do
    talents = get_talents_for_role(player.role)

    # 2枚をランダムに選択
    selected_talents =
      talents
      |> Enum.shuffle()
      |> Enum.take(2)

    Enum.each(selected_talents, fn talent ->
      %PlayerTalent{}
      |> PlayerTalent.changeset(%{
        player_id: player.id,
        talent_card_id: talent.id,
        is_used: false
      })
      |> Repo.insert!()
    end)

    selected_talents
  end

  @doc """
  プレイヤーのタレントを取得（使用状態含む）
  """
  def get_player_talents(%Player{} = player) do
    player = Repo.preload(player, player_talents: :talent_card)

    Enum.map(player.player_talents, fn pt ->
      %{
        id: pt.talent_card.id,
        name: pt.talent_card.name,
        description: pt.talent_card.description,
        category: pt.talent_card.category,
        compatible_tags: pt.talent_card.compatible_tags,
        effect_type: pt.talent_card.effect_type,
        effect_value: pt.talent_card.effect_value,
        is_used: pt.is_used,
        player_talent_id: pt.id
      }
    end)
  end

  @doc """
  タレントを使用
  """
  def use_talent(%PlayerTalent{} = player_talent) do
    player_talent
    |> PlayerTalent.changeset(%{is_used: true})
    |> Repo.update()
  end

  @doc """
  タレントIDで使用済みにする
  """
  def use_talent_by_id(player_talent_id) do
    player_talent = Repo.get!(PlayerTalent, player_talent_id)
    use_talent(player_talent)
  end

  @doc """
  タレントがアクションカードと互換性があるかチェック
  """
  def talent_compatible_with_action?(%TalentCard{} = talent, %ActionCard{} = action_card) do
    TalentCard.compatible_with?(talent, action_card.category)
  end

  @doc """
  プレイヤーの未使用タレントで互換性のあるものを取得
  """
  def get_compatible_talents(%Player{} = player, %ActionCard{} = action_card) do
    player = Repo.preload(player, player_talents: :talent_card)

    player.player_talents
    |> Enum.filter(fn pt ->
      not pt.is_used and TalentCard.compatible_with?(pt.talent_card, action_card.category)
    end)
    |> Enum.map(fn pt ->
      %{
        id: pt.talent_card.id,
        name: pt.talent_card.name,
        description: pt.talent_card.description,
        effect_type: pt.talent_card.effect_type,
        effect_value: pt.talent_card.effect_value,
        player_talent_id: pt.id
      }
    end)
  end

  defp role_to_category("forest_guardian"), do: "forest"
  defp role_to_category("heritage_weaver"), do: "culture"
  defp role_to_category("community_keeper"), do: "social"
  defp role_to_category("akasha_architect"), do: "akasha"
  defp role_to_category(_), do: "universal"

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

  # ===================
  # AI自動行動関連
  # ===================

  @doc """
  ゲームセッションIDからフェーズを進める
  """
  def advance_phase_by_session_id(game_session_id) do
    game_session = get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)

    if turn_state do
      next_phase = TurnState.next_phase(turn_state.phase)

      turn_state
      |> TurnState.changeset(%{phase: next_phase})
      |> Repo.update()
      |> case do
        {:ok, _} ->
          updated_session = get_game_session!(game_session_id)
          GamePubSub.broadcast_state_update(game_session_id, updated_session)
          {:ok, updated_session}

        error ->
          error
      end
    else
      {:ok, game_session}
    end
  end

  @doc """
  イベントの効果を適用する
  """
  def apply_event_effects(game_session_id, event_card_id) do
    game_session = get_game_session!(game_session_id)
    event_card = Repo.get(EventCard, event_card_id)

    if event_card do
      # イベントカードの効果を適用
      attrs = %{
        forest: game_session.forest + (event_card.effect_forest || 0),
        culture: game_session.culture + (event_card.effect_culture || 0),
        social: game_session.social + (event_card.effect_social || 0)
      }

      # 値を0〜20の範囲に制限
      attrs = %{
        forest: max(0, min(20, attrs.forest)),
        culture: max(0, min(20, attrs.culture)),
        social: max(0, min(20, attrs.social))
      }

      # 生命指数も更新
      life_index = attrs.forest + attrs.culture + attrs.social
      attrs = Map.put(attrs, :life_index, life_index)

      {:ok, updated_session} = update_game_session(game_session, attrs)
      GamePubSub.broadcast_state_update(game_session_id, updated_session)
      {:ok, updated_session}
    else
      {:ok, game_session}
    end
  end

  @doc """
  discussionフェーズからactionフェーズに進む
  """
  def advance_to_action_phase(game_session_id) do
    game_session = get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)

    if turn_state && turn_state.phase == "discussion" do
      turn_state
      |> TurnState.changeset(%{phase: "action"})
      |> Repo.update()
      |> case do
        {:ok, _} ->
          updated_session = get_game_session!(game_session_id)
          GamePubSub.broadcast_state_update(game_session_id, updated_session)
          {:ok, updated_session}

        error ->
          error
      end
    else
      {:ok, game_session}
    end
  end

  @doc """
  アクションカードを取得
  """
  def get_action_card!(id) do
    Repo.get!(ActionCard, id)
  end

  @doc """
  AIプレイヤーがアクションを実行
  """
  def execute_action(game_session_id, player_id, action_card_id) do
    game_session = get_game_session!(game_session_id)
    player = Enum.find(game_session.players, fn p -> p.id == player_id end)
    action_card = get_action_card!(action_card_id)

    if player && action_card do
      execute_action_card(player, action_card, game_session)
    else
      {:error, :not_found}
    end
  end

  @doc """
  全プレイヤーがアクション完了していたら次のフェーズへ
  """
  def advance_phase_if_ready(game_session_id) do
    game_session = get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)

    if turn_state && turn_state.phase == "action" do
      # actionフェーズ完了後、次のターンへ
      advance_to_next_turn(game_session_id)
    else
      {:ok, game_session}
    end
  end

  @doc """
  次のターンに進む
  """
  def advance_to_next_turn(game_session_id) do
    # デマレージを適用
    apply_demurrage_to_all(game_session_id)

    # ゲーム終了チェック
    updated_session = get_game_session!(game_session_id)
    case check_game_end(updated_session) do
      {:immediate_loss, reason} ->
        {:ok, final_session} = update_game_session(updated_session, %{status: "failed"})
        GamePubSub.broadcast_game_end(final_session.id, reason)
        {:ok, final_session}

      {:completed, ending} ->
        {:ok, final_session} = update_game_session(updated_session, %{status: "completed"})
        GamePubSub.broadcast_game_end(final_session.id, ending)
        {:ok, final_session}

      {:continue, _} ->
        # 次のターンを開始
        {:ok, new_turn_session} = update_game_session(updated_session, %{turn: updated_session.turn + 1})
        {:ok, _turn_state} = start_new_turn(new_turn_session)

        final_session = get_game_session!(game_session_id)
        GamePubSub.broadcast_state_update(game_session_id, final_session)
        {:ok, final_session}
    end
  end

  defp get_current_turn_state(game_session) do
    game_session.turn_states
    |> Enum.sort_by(& &1.turn_number, :desc)
    |> List.first()
  end

  @doc """
  現在のターンでプレイヤーがアクションを実行済みかチェック
  """
  def player_has_acted?(game_session_id, player_id, turn) do
    from(ga in GameAction,
      where:
        ga.game_session_id == ^game_session_id and
          ga.player_id == ^player_id and
          ga.turn == ^turn
    )
    |> Repo.exists?()
  end

  @doc """
  現在のターンで全プレイヤーがアクションを実行済みかチェック
  """
  def all_players_acted?(game_session_id, turn) do
    game_session = get_game_session!(game_session_id)
    player_ids = Enum.map(game_session.players, & &1.id)

    # 各プレイヤーがアクションを実行済みかチェック
    Enum.all?(player_ids, fn player_id ->
      player_has_acted?(game_session_id, player_id, turn)
    end)
  end

  @doc """
  全プレイヤーがアクション完了した場合、呼吸フェーズへ進む
  新しいフロー: action → breathing → musuhi → end → kami_hakari（次のターン）
  """
  def check_and_advance_turn(game_session_id) do
    game_session = get_game_session!(game_session_id)
    turn_state = get_current_turn_state(game_session)

    if turn_state && turn_state.phase == "action" do
      if all_players_acted?(game_session_id, game_session.turn) do
        # 全プレイヤーがアクション完了、呼吸フェーズへ移行
        advance_phase(game_session_id)
      else
        {:ok, game_session}
      end
    else
      {:ok, game_session}
    end
  end

  @doc """
  プレイヤーがまだアクションを実行していない場合のみアクションを実行
  """
  def execute_action_if_not_acted(game_session_id, player_id, action_card_id) do
    game_session = get_game_session!(game_session_id)

    if player_has_acted?(game_session_id, player_id, game_session.turn) do
      {:error, :already_acted}
    else
      execute_action(game_session_id, player_id, action_card_id)
    end
  end

  @doc """
  プレイヤーがパス（アクションをスキップ）
  """
  def pass_action(game_session_id, player_id) do
    game_session = get_game_session!(game_session_id)
    player = Enum.find(game_session.players, fn p -> p.id == player_id end)

    if player && not player_has_acted?(game_session_id, player_id, game_session.turn) do
      # パスアクションを記録
      %GameAction{}
      |> GameAction.changeset(%{
        game_session_id: game_session_id,
        player_id: player_id,
        turn: game_session.turn,
        action_type: "pass",
        details: %{}
      })
      |> Repo.insert()
      |> case do
        {:ok, _} ->
          # 全プレイヤーがアクション完了したかチェック
          check_and_advance_turn(game_session_id)

        error ->
          error
      end
    else
      {:error, :already_acted}
    end
  end

  @doc """
  現在のターンでアクションを実行していないプレイヤーを取得
  """
  def get_players_not_acted(game_session_id) do
    game_session = get_game_session!(game_session_id)

    game_session.players
    |> Enum.reject(fn player ->
      player_has_acted?(game_session_id, player.id, game_session.turn)
    end)
  end

  # ===================
  # 邪気・オロチシステム
  # ===================

  @doc """
  邪気を追加（共有プールへ）
  amount: 増減量（マイナス値も可）
  """
  def add_evil(%GameSession{} = game_session, amount) do
    new_evil_pool = max(0, game_session.evil_pool + amount)
    update_game_session(game_session, %{evil_pool: new_evil_pool})
  end

  @doc """
  プレイヤーに邪気トークンを追加
  """
  def add_player_evil(%Player{} = player, amount) do
    new_evil = max(0, player.evil_tokens + amount)

    player
    |> Player.changeset(%{evil_tokens: new_evil})
    |> Repo.update()
  end

  @doc """
  ゲームセッションとプレイヤーIDから、特定プレイヤーに邪気トークンを追加
  """
  def add_player_evil(%GameSession{} = game_session, player_id, amount) do
    player = Enum.find(game_session.players, fn p -> p.id == player_id end)

    if player do
      {:ok, _updated_player} = add_player_evil(player, amount)
      {:ok, get_game_session!(game_session.id)}
    else
      {:error, :player_not_found}
    end
  end

  @doc """
  邪気プールからオロチへの変換をチェック・実行
  邪気がthreshold以上になるとオロチレベルが上がる
  """
  def advance_orochi_if_needed(%GameSession{} = game_session) do
    if game_session.evil_pool >= game_session.evil_threshold and game_session.orochi_level < 3 do
      new_evil_pool = game_session.evil_pool - game_session.evil_threshold
      new_orochi_level = game_session.orochi_level + 1

      {:ok, updated} =
        update_game_session(game_session, %{
          evil_pool: new_evil_pool,
          orochi_level: new_orochi_level
        })

      # 再帰的にチェック（まだ邪気がthreshold以上ならさらに進める）
      advance_orochi_if_needed(updated)
    else
      {:ok, game_session}
    end
  end

  @doc """
  オロチレベルに応じたペナルティを適用
  Lv1: F-1, Lv2: K-1, Lv3: S-1
  """
  def apply_orochi_penalty(%GameSession{} = game_session) do
    case game_session.orochi_level do
      1 ->
        new_forest = max(0, game_session.forest - 1)
        update_game_session(game_session, %{forest: new_forest})

      2 ->
        new_culture = max(0, game_session.culture - 1)
        update_game_session(game_session, %{culture: new_culture})

      3 ->
        new_social = max(0, game_session.social - 1)
        update_game_session(game_session, %{social: new_social})

      _ ->
        {:ok, game_session}
    end
  end

  # ===================
  # 神議り（方針設定）フェーズ
  # ===================

  @doc """
  今年の方針を設定（神議りフェーズ）
  policy: "forest" | "culture" | "community" | "purify"
  """
  def set_policy(game_session_id, policy) when policy in ~w(forest culture community purify) do
    game_session = get_game_session!(game_session_id)

    {:ok, updated} = update_game_session(game_session, %{current_policy: policy})

    # イベントフェーズへ進める
    turn_state = get_current_turn_state(updated)
    if turn_state && turn_state.phase == "kami_hakari" do
      advance_phase(turn_state)
    end

    GamePubSub.broadcast_state_update(game_session_id, updated)
    {:ok, updated}
  end

  def set_policy(_game_session_id, _policy), do: {:error, :invalid_policy}

  @doc """
  方針違反をチェックし、邪気を追加
  例: 方針が:forestなのにforestが減った場合
  """
  def check_policy_violation(%GameSession{} = game_session, old_values) do
    case game_session.current_policy do
      "forest" when game_session.forest < old_values.forest ->
        add_evil(game_session, 1)

      "culture" when game_session.culture < old_values.culture ->
        add_evil(game_session, 1)

      "community" when game_session.social < old_values.social ->
        add_evil(game_session, 1)

      _ ->
        {:ok, game_session}
    end
  end

  # ===================
  # 呼吸フェーズ（還流・禊）
  # ===================

  @doc """
  呼吸フェーズを実行
  - P>=5のプレイヤーは自動還流（P-1、邪気-1）
  - 任意で追加還流も可能
  """
  def execute_breathing_phase(game_session_id) do
    game_session = get_game_session!(game_session_id)

    # 各プレイヤーの自動還流
    Enum.each(game_session.players, fn player ->
      if player.akasha >= 5 do
        # 自動還流: P-1、邪気-1
        {:ok, _} = update_player_akasha(player, -1)
        {:ok, _} = add_player_evil(player, -1)
      end
    end)

    # フェーズを進める
    turn_state = get_current_turn_state(game_session)
    if turn_state && turn_state.phase == "breathing" do
      advance_phase(turn_state)
    end

    updated_session = get_game_session!(game_session_id)
    GamePubSub.broadcast_state_update(game_session_id, updated_session)
    {:ok, updated_session}
  end

  @doc """
  プレイヤーが追加還流（任意）
  amount: 還流するP量
  target: "forest" | "culture" | "social"（どの基金に還流するか）
  """
  def voluntary_circulation(%Player{} = player, amount, target)
      when amount > 0 and target in ~w(forest culture social) do
    if player.akasha >= amount do
      # Pを減らす
      {:ok, updated_player} = update_player_akasha(player, -amount)
      # 邪気も減らす（還流量と同じ）
      {:ok, _} = add_player_evil(updated_player, -amount)

      # 対応するパラメータを増やす（将来的に実装）
      # 今は単に還流したことを記録

      {:ok, updated_player}
    else
      {:error, :insufficient_akasha}
    end
  end

  # ===================
  # 結び（musuhi）フェーズ
  # ===================

  @doc """
  結びフェーズを実行
  - 称号の付与（将来実装）
  - 感謝の表現（将来実装）
  """
  def execute_musuhi_phase(game_session_id) do
    game_session = get_game_session!(game_session_id)

    # 将来的に称号付与ロジックを追加

    # フェーズを進める
    turn_state = get_current_turn_state(game_session)
    if turn_state && turn_state.phase == "musuhi" do
      advance_phase(turn_state)
    end

    updated_session = get_game_session!(game_session_id)
    GamePubSub.broadcast_state_update(game_session_id, updated_session)
    {:ok, updated_session}
  end

  @doc """
  プレイヤーに称号を付与
  """
  def grant_title(%Player{} = player, title) when is_binary(title) do
    new_titles = Enum.uniq([title | player.titles || []])

    player
    |> Player.changeset(%{titles: new_titles})
    |> Repo.update()
  end

  # ===================
  # ターン終了処理（年末）
  # ===================

  @doc """
  年末処理を実行
  - 邪気→オロチ変換チェック
  - オロチペナルティ適用
  - 勝敗判定
  """
  def execute_end_of_turn(game_session_id) do
    game_session = get_game_session!(game_session_id)

    # 邪気→オロチ変換
    {:ok, game_session} = advance_orochi_if_needed(game_session)

    # オロチペナルティ適用
    {:ok, game_session} = apply_orochi_penalty(game_session)

    # 生命指数更新
    {:ok, game_session} = update_life_index(game_session)

    # 方針をリセット
    {:ok, game_session} = update_game_session(game_session, %{current_policy: nil})

    # 勝敗判定
    case check_game_end(game_session) do
      {:immediate_loss, reason} ->
        {:ok, final_session} = update_game_session(game_session, %{status: "failed"})
        GamePubSub.broadcast_game_end(final_session.id, reason)
        {:game_over, reason, final_session}

      {:completed, ending} ->
        {:ok, final_session} = update_game_session(game_session, %{status: "completed"})
        GamePubSub.broadcast_game_end(final_session.id, ending)
        {:game_over, ending, final_session}

      {:continue, _} ->
        # 次のターンへ
        {:ok, new_session} = update_game_session(game_session, %{turn: game_session.turn + 1})
        {:ok, _turn_state} = start_new_turn_with_kami_hakari(new_session)

        final_session = get_game_session!(game_session_id)
        GamePubSub.broadcast_state_update(game_session_id, final_session)
        {:continue, final_session}
    end
  end

  @doc """
  神議りフェーズから始まる新しいターンを開始
  """
  def start_new_turn_with_kami_hakari(%GameSession{} = game_session) do
    event_card = draw_event_card()
    action_cards = draw_action_cards(5)
    action_card_ids = Enum.map(action_cards, & &1.id)

    turn_state_attrs = %{
      game_session_id: game_session.id,
      turn_number: game_session.turn,
      phase: "kami_hakari",  # 神議りからスタート
      available_cards: action_card_ids,
      current_event_id: if(event_card, do: event_card.id, else: nil)
    }

    %TurnState{}
    |> TurnState.changeset(turn_state_attrs)
    |> Repo.insert()
  end
end
