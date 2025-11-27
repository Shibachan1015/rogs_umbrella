defmodule Shinkanki.Games.CardEngine do
  @moduledoc """
  カードの効果計算とバリデーション
  """

  alias Shinkanki.Games.{ActionCard, EventCard, Player, GameSession}

  @doc """
  アクションカードの効果を計算（役割ボーナス込み）
  """
  def calculate_action_effects(%ActionCard{} = card, %Player{} = player) do
    role_bonus = Player.role_bonus(player.role, card.category)

    %{
      forest: card.effect_forest + bonus_for_category(:forest, card.category, role_bonus),
      culture: card.effect_culture + bonus_for_category(:culture, card.category, role_bonus),
      social: card.effect_social + bonus_for_category(:social, card.category, role_bonus),
      akasha: card.effect_akasha
    }
  end

  defp bonus_for_category(category, card_category, bonus) do
    if Atom.to_string(category) == card_category, do: bonus, else: 0
  end

  @doc """
  アクションカードのコストを支払えるかチェック
  """
  def can_pay_costs?(%ActionCard{} = card, %Player{} = player, %GameSession{} = game_session) do
    forest_ok = game_session.forest >= card.cost_forest
    culture_ok = game_session.culture >= card.cost_culture
    social_ok = game_session.social >= card.cost_social
    akasha_ok = player.akasha >= card.cost_akasha

    forest_ok and culture_ok and social_ok and akasha_ok
  end

  @doc """
  イベントカードの効果を計算
  """
  def calculate_event_effects(event, choice \\ nil)

  def calculate_event_effects(%EventCard{has_choice: false} = event, _choice) do
    %{
      forest: event.effect_forest,
      culture: event.effect_culture,
      social: event.effect_social,
      akasha: event.effect_akasha
    }
  end

  def calculate_event_effects(%EventCard{has_choice: true} = event, choice) do
    case choice do
      :choice_a ->
        event.choice_a_effects || %{}

      :choice_b ->
        event.choice_b_effects || %{}

      _ ->
        %{forest: 0, culture: 0, social: 0, akasha: 0}
    end
  end

  @doc """
  効果をゲームセッションに適用
  F/K/Sが0〜20の範囲内に収まるよう制限
  """
  def apply_effects(%GameSession{} = game_session, effects) do
    new_forest = clamp(game_session.forest + Map.get(effects, :forest, 0), 0, 20)
    new_culture = clamp(game_session.culture + Map.get(effects, :culture, 0), 0, 20)
    new_social = clamp(game_session.social + Map.get(effects, :social, 0), 0, 20)

    %{
      forest: new_forest,
      culture: new_culture,
      social: new_social,
      life_index: new_forest + new_culture + new_social
    }
  end

  @doc """
  コストをゲームセッションとプレイヤーから差し引く
  """
  def deduct_costs(%ActionCard{} = card, %Player{} = player, %GameSession{} = game_session) do
    game_session_updates = %{
      forest: game_session.forest - card.cost_forest,
      culture: game_session.culture - card.cost_culture,
      social: game_session.social - card.cost_social
    }

    player_updates = %{
      akasha: player.akasha - card.cost_akasha
    }

    {game_session_updates, player_updates}
  end

  @doc """
  カード実行の全処理（コストチェック、効果計算、適用）
  """
  def execute_card(%ActionCard{} = card, %Player{} = player, %GameSession{} = game_session) do
    if can_pay_costs?(card, player, game_session) do
      # 効果計算
      effects = calculate_action_effects(card, player)

      # コスト計算
      {session_costs, player_costs} = deduct_costs(card, player, game_session)

      # 効果適用（コスト差し引き後）
      intermediate_session = %{game_session |
        forest: game_session.forest - session_costs.forest,
        culture: game_session.culture - session_costs.culture,
        social: game_session.social - session_costs.social
      }

      final_updates = apply_effects(intermediate_session, effects)

      {:ok, %{
        game_session_updates: final_updates,
        player_updates: player_costs
      }}
    else
      {:error, :insufficient_resources}
    end
  end

  @doc """
  イベントカード実行
  """
  def execute_event(%EventCard{} = event, %GameSession{} = game_session, choice \\ nil) do
    effects = calculate_event_effects(event, choice)
    updates = apply_effects(game_session, effects)

    {:ok, %{game_session_updates: updates}}
  end

  # ヘルパー関数

  defp clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end
end
