defmodule Shinkanki.OrochiRenkeiTest do
  use ExUnit.Case, async: true

  alias Shinkanki.{Game, Card}

  describe "八岐大蛇システム" do
    test "ゲーム開始時に八岐大蛇レベルは1" do
      game = Game.new("test_room")
      assert game.orochi_level == 1
    end

    test "邪気が8になると八岐大蛇が覚醒する" do
      game =
        Game.new("test_room")
        |> Map.put(:jaki, 7)
        |> Map.put(:status, :playing)

      # 邪気を8に更新
      updated_game = Game.update_stats(game, %{jaki: 1})
      assert updated_game.jaki == 8
      assert updated_game.orochi_level == 2
    end

    test "八岐大蛇レベルは最大3" do
      game =
        Game.new("test_room")
        |> Map.put(:orochi_level, 3)
        |> Map.put(:jaki, 7)
        |> Map.put(:status, :playing)

      # 邪気を8に更新しても、レベル3から上がらない
      updated_game = Game.update_stats(game, %{jaki: 1})
      assert updated_game.orochi_level == 3
    end

    test "orochi_status関数でUI用データを取得できる" do
      game =
        Game.new("test_room")
        |> Map.put(:orochi_level, 2)
        |> Map.put(:jaki, 6)

      status = Game.orochi_status(game)
      assert status.level == 2
      assert status.max_level == 3
      assert status.status == "覚醒"
      assert status.warning == "⚠️ 覚醒間近"
    end
  end

  describe "連携カードシステム" do
    setup do
      game =
        Game.new("test_room")
        |> then(fn g ->
          {:ok, g} = Game.join(g, "player1", "プレイヤー1")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.join(g, "player2", "プレイヤー2")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.start_game(g)
          g
        end)

      {:ok, game: game}
    end

    test "連携カードが定義されている" do
      renkei_cards = Card.list_renkei()
      assert length(renkei_cards) > 0

      # 特定のカードが存在することを確認
      assert Enum.any?(renkei_cards, &(&1.id == :r_collective_prayer))
      assert Enum.any?(renkei_cards, &(&1.id == :r_orochi_seal))
    end

    test "連携カードを取得できる" do
      card = Card.get_renkei(:r_collective_prayer)
      assert card != nil
      assert card.name == "大祓の祈り（おおはらいのいのり）"
      assert card.required_players == 2
      assert card.cost_per_player == 2
    end

    test "連携カードを提案できる", %{game: game} do
      {:ok, new_game} = Game.initiate_renkei(game, "player1", :r_collective_prayer)

      # pending_renkeiに追加されていることを確認
      assert Map.has_key?(new_game.pending_renkei, :r_collective_prayer)
      pending = Map.get(new_game.pending_renkei, :r_collective_prayer)
      assert pending.initiator == "player1"
      assert "player1" in pending.participants
    end

    test "同じ連携カードを重複して提案できない", %{game: game} do
      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)
      {:error, :renkei_already_pending} =
        Game.initiate_renkei(game_with_pending, "player2", :r_collective_prayer)
    end

    test "連携に参加できる", %{game: game} do
      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)
      {:ok, new_game} = Game.join_renkei(game_with_pending, "player2", :r_collective_prayer)

      # 2人必要なカードなので、発動して completed_renkei に移動
      assert :r_collective_prayer in new_game.completed_renkei
      assert not Map.has_key?(new_game.pending_renkei, :r_collective_prayer)
    end

    test "連携発動で効果が適用される", %{game: game} do
      initial_jaki = game.jaki

      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)
      {:ok, new_game} = Game.join_renkei(game_with_pending, "player2", :r_collective_prayer)

      # 邪気が減少していることを確認（効果: %{jaki: -2, culture: 1}）
      assert new_game.jaki < initial_jaki
    end

    test "連携をキャンセルできる", %{game: game} do
      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)

      # 提案者がキャンセル
      {:ok, cancelled_game} = Game.cancel_renkei(game_with_pending, "player1", :r_collective_prayer)
      assert not Map.has_key?(cancelled_game.pending_renkei, :r_collective_prayer)
    end

    test "提案者以外はキャンセルできない", %{game: game} do
      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)

      # 非提案者がキャンセル試行
      {:error, :not_initiator} =
        Game.cancel_renkei(game_with_pending, "player2", :r_collective_prayer)
    end

    test "available_renkei_cardsで利用可能なカードを取得できる", %{game: game} do
      available = Game.available_renkei_cards(game)
      assert length(available) > 0

      # 連携を開始すると利用可能リストから除外される
      {:ok, game_with_pending} = Game.initiate_renkei(game, "player1", :r_collective_prayer)
      available_after = Game.available_renkei_cards(game_with_pending)
      assert not Enum.any?(available_after, &(&1.id == :r_collective_prayer))
    end
  end

  describe "八岐大蛇封印の儀（全員参加連携）" do
    test "4人参加で八岐大蛇レベルが下がる" do
      game =
        Game.new("test_room")
        |> Map.put(:orochi_level, 2)
        |> then(fn g ->
          {:ok, g} = Game.join(g, "p1", "プレイヤー1")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.join(g, "p2", "プレイヤー2")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.join(g, "p3", "プレイヤー3")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.join(g, "p4", "プレイヤー4")
          g
        end)
        |> then(fn g ->
          {:ok, g} = Game.start_game(g)
          g
        end)

      initial_orochi_level = game.orochi_level

      # 4人必要な連携を発動
      {:ok, g1} = Game.initiate_renkei(game, "p1", :r_orochi_seal)
      {:ok, g2} = Game.join_renkei(g1, "p2", :r_orochi_seal)
      {:ok, g3} = Game.join_renkei(g2, "p3", :r_orochi_seal)
      {:ok, g4} = Game.join_renkei(g3, "p4", :r_orochi_seal)

      # 八岐大蛇レベルが下がったことを確認
      assert g4.orochi_level < initial_orochi_level
    end
  end
end
