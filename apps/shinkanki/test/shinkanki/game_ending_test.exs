defmodule Shinkanki.GameEndingTest do
  use ExUnit.Case
  alias Shinkanki.Game

  describe "ending type determination" do
    test "神々の祝福エンディング (L >= 40)" do
      # Turn 21 with high Life Index
      # Disable event cards by emptying the deck
      game = %Game{
        Game.new("room")
        | turn: 20,
          forest: 20,
          culture: 15,
          social: 10,
          life_index: 45,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :won
      assert result.ending_type == :blessing
      assert Game.ending_name(result.ending_type) == "🌈 神々の祝福エンディング"
    end

    test "浄化の兆しエンディング (30 <= L < 40)" do
      # Turn 21 with moderate Life Index
      # Disable event cards by emptying the deck
      game = %Game{
        Game.new("room")
        | turn: 20,
          forest: 12,
          culture: 10,
          social: 8,
          life_index: 30,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :won
      assert result.ending_type == :purification
      assert Game.ending_name(result.ending_type) == "🌿 浄化の兆しエンディング"
    end

    test "揺らぎの未来エンディング (20 <= L < 30)" do
      # Turn 21 with low Life Index
      # Disable event cards by emptying the deck
      game = %Game{
        Game.new("room")
        | turn: 20,
          forest: 8,
          culture: 7,
          social: 5,
          life_index: 20,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :lost
      assert result.ending_type == :uncertainty
      assert Game.ending_name(result.ending_type) == "🌙 揺らぎの未来エンディング"
    end

    test "神々の嘆きエンディング (L <= 19)" do
      # Turn 21 with very low Life Index
      # Disable event cards by emptying the deck
      game = %Game{
        Game.new("room")
        | turn: 20,
          forest: 7,
          culture: 6,
          social: 5,
          life_index: 18,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :lost
      assert result.ending_type == :lament
      assert Game.ending_name(result.ending_type) == "🔥 神々の嘆き（文明崩壊）"
    end

    test "即時ゲームオーバー (F=0 or K=0 or S=0)" do
      # Forest becomes 0
      # Disable event cards by emptying the deck
      game = %Game{
        Game.new("room")
        | turn: 5,
          forest: 0,
          culture: 10,
          social: 10,
          life_index: 20,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :lost
      assert result.ending_type == :instant_loss
      assert Game.ending_name(result.ending_type) == "💀 即時ゲームオーバー"

      # Culture becomes 0
      game2 = %Game{
        Game.new("room")
        | turn: 5,
          forest: 10,
          culture: 0,
          social: 10,
          life_index: 20,
          event_deck: [],
          event_discard_pile: []
      }

      result2 = Game.next_turn(game2)

      assert result2.status == :lost
      assert result2.ending_type == :instant_loss

      # Social becomes 0
      game3 = %Game{
        Game.new("room")
        | turn: 5,
          forest: 10,
          culture: 10,
          social: 0,
          life_index: 20,
          event_deck: [],
          event_discard_pile: []
      }

      result3 = Game.next_turn(game3)

      assert result3.status == :lost
      assert result3.ending_type == :instant_loss
    end

    test "ending boundaries are correct" do
      # Disable event cards for all boundary tests
      base_game = %Game{Game.new("room") | event_deck: [], event_discard_pile: []}

      # Test boundary at L = 40 (should be blessing)
      game_40 = %{base_game | turn: 20, forest: 15, culture: 15, social: 10, life_index: 40}
      result_40 = Game.next_turn(game_40)
      assert result_40.ending_type == :blessing

      # Test boundary at L = 39 (should be purification)
      game_39 = %{base_game | turn: 20, forest: 15, culture: 14, social: 10, life_index: 39}
      result_39 = Game.next_turn(game_39)
      assert result_39.ending_type == :purification

      # Test boundary at L = 30 (should be purification)
      game_30 = %{base_game | turn: 20, forest: 12, culture: 10, social: 8, life_index: 30}
      result_30 = Game.next_turn(game_30)
      assert result_30.ending_type == :purification

      # Test boundary at L = 29 (should be uncertainty)
      game_29 = %{base_game | turn: 20, forest: 12, culture: 9, social: 8, life_index: 29}
      result_29 = Game.next_turn(game_29)
      assert result_29.ending_type == :uncertainty

      # Test boundary at L = 20 (should be uncertainty)
      game_20 = %{base_game | turn: 20, forest: 8, culture: 7, social: 5, life_index: 20}
      result_20 = Game.next_turn(game_20)
      assert result_20.ending_type == :uncertainty

      # Test boundary at L = 19 (should be lament)
      game_19 = %{base_game | turn: 20, forest: 7, culture: 7, social: 5, life_index: 19}
      result_19 = Game.next_turn(game_19)
      assert result_19.ending_type == :lament
    end

    test "ending descriptions are available" do
      assert Game.ending_description(:blessing) != nil
      assert Game.ending_description(:purification) != nil
      assert Game.ending_description(:uncertainty) != nil
      assert Game.ending_description(:lament) != nil
      assert Game.ending_description(:instant_loss) != nil
      assert Game.ending_description(nil) == nil
    end

    test "game continues playing if turn <= 20 and stats > 0" do
      # Turn 20 should not trigger ending (turn > 20 is required)
      game = %Game{
        Game.new("room")
        | turn: 19,
          forest: 10,
          culture: 10,
          social: 10,
          life_index: 30,
          event_deck: [],
          event_discard_pile: []
      }

      result = Game.next_turn(game)

      assert result.status == :playing
      assert result.ending_type == nil
    end
  end
end
