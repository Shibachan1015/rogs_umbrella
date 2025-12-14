defmodule Shinkanki.AI.ClaudeAgent do
  @moduledoc """
  Claude API を使用したAIエージェント。
  各CPUプレイヤーの思考過程を日本語で出力し、最善手を決定する。
  """

  alias Shinkanki.{Game, Card}

  require Logger

  @claude_api_url "https://api.anthropic.com/v1/messages"
  @model "claude-sonnet-4-20250514"

  # AIプレイヤーのキャラクター設定
  @ai_characters %{
    1 => %{
      name: "森の精霊ミドリ",
      personality: "自然を愛する穏やかな存在。森（F）の保護を最優先に考える。",
      speech_style: "「〜なの」「〜だわ」という柔らかい口調",
      emoji: "🌳"
    },
    2 => %{
      name: "文化の守人カグラ",
      personality: "伝統と知恵を重んじる賢者。文化（K）の維持を大切にする。",
      speech_style: "「〜でございます」「〜かと存じます」という丁寧な口調",
      emoji: "🎎"
    },
    3 => %{
      name: "絆の使者ムスビ",
      personality: "人々の絆を結ぶ温かい存在。コミュニティ（S）の強化を重視する。",
      speech_style: "「〜だね」「〜しよう！」という親しみやすい口調",
      emoji: "🤝"
    },
    4 => %{
      name: "空環の賢者アカシャ",
      personality: "バランスと調和を求める知恵者。全体のバランスを見て判断する。",
      speech_style: "「〜であろう」「〜と思われる」という落ち着いた口調",
      emoji: "✨"
    }
  }

  @doc """
  AIプレイヤーのアクションを決定し、思考過程を会話として出力する。
  Returns: {:ok, action_id, talent_ids, thoughts} or {:error, reason}
  """
  def decide_action(%Game{} = game, player_id) do
    player = Map.get(game.players, player_id)
    ai_index = get_ai_index(game, player_id)
    character = Map.get(@ai_characters, ai_index, @ai_characters[1])

    case Application.get_env(:shinkanki, :ai_provider, :local) do
      :claude ->
        decide_with_claude(game, player_id, player, character)

      :local ->
        # フォールバック: ローカルAIを使用
        decide_with_local(game, player_id, player, character)
    end
  end

  @doc """
  神議りフェーズでAIプレイヤーの意見を生成する。
  """
  def discuss(%Game{} = game, player_id) do
    player = Map.get(game.players, player_id)
    ai_index = get_ai_index(game, player_id)
    character = Map.get(@ai_characters, ai_index, @ai_characters[1])

    case Application.get_env(:shinkanki, :ai_provider, :local) do
      :claude ->
        discuss_with_claude(game, player, character)

      :local ->
        discuss_with_local(game, player, character)
    end
  end

  # Claude API を使用してアクションを決定
  defp decide_with_claude(game, player_id, player, character) do
    api_key = Application.get_env(:shinkanki, :claude_api_key)

    if is_nil(api_key) do
      Logger.warning("Claude API key not configured, falling back to local AI")
      decide_with_local(game, player_id, player, character)
    else
      prompt = build_action_prompt(game, player_id, player, character)

      case call_claude_api(api_key, prompt) do
        {:ok, response} ->
          parse_action_response(response, game, player_id, player, character)

        {:error, reason} ->
          Logger.error("Claude API error: #{inspect(reason)}, falling back to local AI")
          decide_with_local(game, player_id, player, character)
      end
    end
  end

  # 神議りフェーズのClaude呼び出し
  defp discuss_with_claude(game, player, character) do
    api_key = Application.get_env(:shinkanki, :claude_api_key)

    if is_nil(api_key) do
      discuss_with_local(game, player, character)
    else
      prompt = build_discussion_prompt(game, player, character)

      case call_claude_api(api_key, prompt) do
        {:ok, response} ->
          {:ok, format_discussion(response, character)}

        {:error, _reason} ->
          discuss_with_local(game, player, character)
      end
    end
  end

  # アクション決定用のプロンプト構築
  defp build_action_prompt(game, player_id, player, character) do
    hand = Map.get(game.hands, player_id, [])
    playable_cards = get_playable_cards(game, hand)

    """
    あなたは「神環記」という協力型ボードゲームのAIプレイヤーです。

    【あなたのキャラクター】
    名前: #{character.name}
    性格: #{character.personality}
    口調: #{character.speech_style}

    【現在のゲーム状態】
    - 年: #{game.turn}年目 / 20年
    - フェーズ: #{phase_name(game.phase)}
    - 森（F）: #{game.forest}/10
    - 文化（K）: #{game.culture}/10
    - コミュニティ（S）: #{game.social}/10
    - 邪気: #{game.jaki}/8
    - いのち指数: #{game.life_index} (F+K+S)
    - 共有空環: #{game.currency}
    - あなたの空環: #{player.kuukan}

    【勝利条件】
    20年後のいのち指数（L = F + K + S）によってエンディングが決まります。
    - L >= 24: 神々の祝福エンディング（最高）
    - L >= 18: 浄化の兆しエンディング
    - L >= 12: 揺らぎの未来エンディング
    - L < 12: 神々の嘆き（敗北）
    ※ F, K, S のどれかが0になると即ゲームオーバー

    【使用可能なカード】
    #{format_playable_cards(playable_cards)}

    【あなたのタスク】
    1. まず、現在の状況を分析してください
    2. 他のプレイヤーへの呼びかけを含めて、あなたの考えを日本語で話してください
    3. 最後に、選んだカードのIDを出力してください

    出力形式:
    ```thought
    [キャラクターの口調で、状況分析と他のプレイヤーへの呼びかけを2-3文で]
    ```
    ```action
    [選んだカードのID（例: :shokurin）]
    ```
    """
  end

  # 神議りフェーズ用のプロンプト
  defp build_discussion_prompt(game, _player, character) do
    """
    あなたは「神環記」という協力型ボードゲームのAIプレイヤーです。

    【あなたのキャラクター】
    名前: #{character.name}
    性格: #{character.personality}
    口調: #{character.speech_style}

    【現在のゲーム状態】
    - 年: #{game.turn}年目 / 20年
    - フェーズ: 神議り（今年の方針を決める話し合い）
    - 森（F）: #{game.forest}/10
    - 文化（K）: #{game.culture}/10
    - コミュニティ（S）: #{game.social}/10
    - 邪気: #{game.jaki}/8
    - いのち指数: #{game.life_index}

    【選べる年間方針】
    🌳 森を守る年（F優先）
    🎎 文化を守る年（K優先）
    🤝 コミュニティを立て直す年（S優先）
    🧹 邪気をできるだけ減らす年（浄化優先）

    【タスク】
    キャラクターの口調で、今年どの方針を取るべきか、他のプレイヤーに提案してください。
    1-2文で簡潔に、状況を踏まえた意見を述べてください。
    """
  end

  # Claude API呼び出し
  defp call_claude_api(api_key, prompt) do
    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: @model,
        max_tokens: 500,
        messages: [
          %{role: "user", content: prompt}
        ]
      })

    case :httpc.request(
           :post,
           {~c"#{@claude_api_url}", headers |> Enum.map(fn {k, v} -> {~c"#{k}", ~c"#{v}"} end),
            ~c"application/json", body},
           [timeout: 30_000, connect_timeout: 10_000],
           []
         ) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        # Convert charlist to binary with proper UTF-8 encoding
        body_string = :erlang.list_to_binary(response_body)
        case Jason.decode(body_string) do
          {:ok, %{"content" => [%{"text" => text} | _]}} ->
            {:ok, text}

          _ ->
            {:error, :invalid_response}
        end

      {:ok, {{_, status, _}, _headers, response_body}} ->
        Logger.error("Claude API returned #{status}: #{response_body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # レスポンスをパースしてアクションを抽出
  defp parse_action_response(response, game, player_id, player, character) do
    # 思考部分を抽出
    thought =
      case Regex.run(~r/```thought\s*\n?(.*?)\n?```/s, response) do
        [_, thought] -> String.trim(thought)
        _ -> extract_thought_fallback(response, character)
      end

    # アクション部分を抽出
    action_id =
      case Regex.run(~r/```action\s*\n?:?(\w+)\n?```/s, response) do
        [_, action] -> String.to_existing_atom(action)
        _ -> nil
      end

    hand = Map.get(game.hands, player_id, [])

    if action_id && action_id in hand do
      talent_ids = select_talents_for_card(player, action_id)
      formatted_thought = "#{character.emoji} #{character.name}: #{thought}"
      {:ok, action_id, talent_ids, formatted_thought}
    else
      # フォールバック: ローカルAIで決定
      case Shinkanki.AI.select_action(game, player_id) do
        {:ok, fallback_action, talent_ids} ->
          formatted_thought = "#{character.emoji} #{character.name}: #{thought}"
          {:ok, fallback_action, talent_ids, formatted_thought}

        error ->
          error
      end
    end
  end

  # フォールバック思考抽出
  defp extract_thought_fallback(response, _character) do
    # レスポンス全体から最初の文を抽出
    response
    |> String.split(~r/[。！？\n]/)
    |> Enum.take(2)
    |> Enum.join("。")
    |> then(fn text ->
      if String.length(text) > 100, do: String.slice(text, 0, 100) <> "...", else: text
    end)
  end

  # ローカルAIでアクション決定（思考付き）
  defp decide_with_local(game, player_id, player, character) do
    case Shinkanki.AI.select_action(game, player_id) do
      {:ok, action_id, talent_ids} ->
        thought = generate_local_thought(game, player, character, action_id)
        formatted_thought = "#{character.emoji} #{character.name}: #{thought}"
        {:ok, action_id, talent_ids, formatted_thought}

      error ->
        error
    end
  end

  # ローカルでの思考生成
  defp generate_local_thought(game, _player, character, action_id) do
    card = Card.get_action(action_id) || Card.get_project(action_id)
    card_name = if card, do: card.name, else: "このカード"

    # 状況に応じた思考を生成
    concerns = []
    concerns = if game.forest <= 3, do: ["森が危険な状態" | concerns], else: concerns
    concerns = if game.culture <= 3, do: ["文化が衰退している" | concerns], else: concerns
    concerns = if game.social <= 3, do: ["コミュニティが弱まっている" | concerns], else: concerns
    concerns = if game.jaki >= 6, do: ["邪気が高い" | concerns], else: concerns

    base_thought =
      case character.name do
        "森の精霊ミドリ" ->
          if game.forest <= 3,
            do: "森がとても心配なの…",
            else: "自然の力を借りて、世界を守りたいの。"

        "文化の守人カグラ" ->
          if game.culture <= 3,
            do: "文化の灯火が消えかけております…",
            else: "伝統の知恵を活かしてまいりましょう。"

        "絆の使者ムスビ" ->
          if game.social <= 3,
            do: "みんなの絆が薄れてきてる…一緒に頑張ろう！",
            else: "みんなで力を合わせれば、きっと大丈夫だね！"

        "空環の賢者アカシャ" ->
          if length(concerns) >= 2,
            do: "バランスが崩れつつある。慎重に行動すべきであろう。",
            else: "調和を保ちながら、前に進むのが賢明であろう。"

        _ ->
          "#{card_name}を使って世界を守ろう。"
      end

    "#{base_thought}「#{card_name}」を使うわね。"
  end

  # ローカルでの議論生成
  defp discuss_with_local(game, _player, character) do
    # 最も低いステータスを特定
    min_stat =
      [{:forest, game.forest}, {:culture, game.culture}, {:social, game.social}]
      |> Enum.min_by(fn {_, v} -> v end)

    suggestion =
      case min_stat do
        {:forest, _} -> "森を守ることを優先すべき"
        {:culture, _} -> "文化の保護が急務"
        {:social, _} -> "コミュニティの立て直しが必要"
      end

    thought =
      case character.name do
        "森の精霊ミドリ" ->
          "今年は#{suggestion}だと思うの。森の声が聞こえるわ…"

        "文化の守人カグラ" ->
          "#{suggestion}かと存じます。先人の知恵を忘れてはなりません。"

        "絆の使者ムスビ" ->
          "#{suggestion}だと思うよ！みんなで協力すれば乗り越えられる！"

        "空環の賢者アカシャ" ->
          "#{suggestion}であろう。全体のバランスを見ながら進めるべきだ。"

        _ ->
          "#{suggestion}だと考えます。"
      end

    {:ok, "#{character.emoji} #{character.name}: #{thought}"}
  end

  # 議論のフォーマット
  defp format_discussion(response, character) do
    # 改行を除去して1行にまとめる
    cleaned =
      response
      |> String.replace(~r/\n+/, " ")
      |> String.trim()
      |> then(fn text ->
        if String.length(text) > 150, do: String.slice(text, 0, 150) <> "...", else: text
      end)

    "#{character.emoji} #{character.name}: #{cleaned}"
  end

  # プレイ可能なカードを取得
  defp get_playable_cards(game, hand) do
    hand
    |> Enum.map(fn card_id ->
      case Card.get_action(card_id) do
        nil -> nil
        card -> if game.currency >= card.cost, do: card, else: nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # カード情報をフォーマット
  defp format_playable_cards([]), do: "（使用可能なカードがありません）"

  defp format_playable_cards(cards) do
    cards
    |> Enum.map(fn card ->
      effect_str =
        card.effect
        |> Enum.map(fn {k, v} -> "#{stat_name(k)}#{if v >= 0, do: "+", else: ""}#{v}" end)
        |> Enum.join(", ")

      "- #{card.id}: #{card.name}（コスト: #{card.cost}）効果: #{effect_str}"
    end)
    |> Enum.join("\n")
  end

  defp stat_name(:forest), do: "F"
  defp stat_name(:culture), do: "K"
  defp stat_name(:social), do: "S"
  defp stat_name(:jaki), do: "邪気"
  defp stat_name(:currency), do: "P"
  defp stat_name(other), do: to_string(other)

  defp phase_name(:hitoyo), do: "人代フェーズ"
  defp phase_name(:kamihakari), do: "神議りフェーズ"
  defp phase_name(:itonami), do: "営みフェーズ"
  defp phase_name(:kokyu), do: "呼吸フェーズ"
  defp phase_name(:musuhi), do: "結びフェーズ"
  defp phase_name(:toshiokuri), do: "年送りフェーズ"
  defp phase_name(other), do: to_string(other)

  # AIプレイヤーのインデックスを取得（1-4）
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

  # カードに対応するタレントを選択
  defp select_talents_for_card(player, card_id) do
    card = Card.get_action(card_id) || Card.get_project(card_id)

    if card do
      available_talents =
        player.talents
        |> Enum.reject(&Enum.member?(player.used_talents, &1))
        |> Enum.map(&Card.get_talent/1)
        |> Enum.reject(&is_nil/1)

      compatible_talents =
        available_talents
        |> Enum.filter(fn talent ->
          Enum.any?(talent.compatible_tags, &Enum.member?(card.tags || [], &1))
        end)

      compatible_talents
      |> Enum.take(2)
      |> Enum.map(& &1.id)
    else
      []
    end
  end
end
