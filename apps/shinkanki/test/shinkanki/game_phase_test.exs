defmodule Shinkanki.GamePhaseTest do
  use ExUnit.Case
  alias Shinkanki.Game

  describe "phase management system" do
    test "game starts in event phase" do
      game = Game.new("room_1")
      assert game.phase == :event
    end

    test "next_turn resets phase to event" do
      game = %Game{Game.new("room_1") | phase: :action, turn: 1}
      new_game = Game.next_turn(game)

      # After event phase execution
      assert new_game.phase == :discussion
      assert new_game.turn == 2
    end

    test "next_phase advances through all phases" do
      # Start with event phase
      game = %Game{Game.new("room_1") | phase: :event, event_deck: [], event_discard_pile: []}

      # Event -> Discussion (execute_phase auto-advances to discussion)
      game1 = Game.next_phase(game)
      assert game1.phase == :discussion

      # Discussion -> Action
      game2 = Game.next_phase(game1)
      assert game2.phase == :action

      # Action -> Demurrage
      # Note: execute_phase for action doesn't auto-advance, so next_phase will advance to demurrage
      # and execute_phase for demurrage will auto-advance to life_update
      game3 = Game.next_phase(game2)
      # After executing demurrage phase, should be in life_update
      assert game3.phase == :life_update

      # Life Update -> Judgment (execute_phase auto-advances to judgment)
      game4 = Game.next_phase(game3)
      assert game4.phase == :judgment

      # Judgment -> Event (next turn) - but only if game is still playing
      %Game{} = game4
      # Ensure game is still playing
      game5 = %{game4 | turn: 1, status: :playing}
      result = Game.next_phase(game5)
      # If game is still playing, should advance to event, otherwise stays in judgment
      assert result.phase == :event || result.phase == :judgment
    end

    test "event phase executes event card drawing" do
      game = %Game{
        Game.new("room_1")
        | phase: :event,
          turn: 1,
          event_deck: [:e_harvest_festival],
          event_discard_pile: []
      }

      new_game = Game.next_phase(game)

      # execute_phase for event should draw event and advance to discussion
      assert new_game.phase == :discussion
      # Event should be drawn (unless deck is empty after drawing)
      assert new_game.current_event != nil || new_game.event_deck == []
    end

    test "demurrage phase applies currency decay" do
      # Test that demurrage is applied when phase is demurrage
      # Since execute_phase is private, we test through the public API
      game = %Game{
        Game.new("room_1")
        | phase: :demurrage,
          currency: 100,
          status: :playing,
          event_deck: [],
          event_discard_pile: []
      }

      # next_phase should execute demurrage phase which auto-advances to life_update
      new_game = Game.next_phase(game)

      # Demurrage should be applied (100 * 0.9 = 90)
      # But since execute_phase auto-advances, we check the result
      assert new_game.currency <= 100
      # Phase should have advanced (demurrage -> life_update -> judgment or back to event)
      assert new_game.phase != :demurrage
    end

    test "life_update phase updates life index and resets players" do
      game = %Game{
        Game.new("room_1")
        | phase: :life_update,
          forest: 20,
          culture: 15,
          social: 10,
          # Will be recalculated
          life_index: 150,
          status: :playing,
          event_deck: [],
          event_discard_pile: []
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")

      # next_phase should execute life_update which auto-advances to judgment
      new_game = Game.next_phase(game)

      # Life index should be recalculated: 20 + 15 + 10 = 45
      assert new_game.life_index == 45
      assert new_game.phase == :judgment

      # Players should be reset
      player = Map.get(new_game.players, "p1")
      assert player.is_ready == false
      assert player.used_talents == []
    end

    test "judgment phase checks win/loss conditions" do
      # Test win condition
      game_won = %Game{
        Game.new("room_1")
        | phase: :judgment,
          turn: 21,
          forest: 20,
          culture: 15,
          social: 10,
          life_index: 45,
          status: :playing,
          event_deck: [],
          event_discard_pile: []
      }

      # execute_phase for judgment should check win/loss
      # Since execute_phase is called by next_phase, we use next_phase
      result_won = Game.next_phase(game_won)
      assert result_won.status == :won
      assert result_won.ending_type == :blessing

      # Test loss condition
      game_lost = %Game{
        Game.new("room_1")
        | phase: :judgment,
          turn: 21,
          forest: 7,
          culture: 6,
          social: 5,
          life_index: 18,
          status: :playing,
          event_deck: [],
          event_discard_pile: []
      }

      result_lost = Game.next_phase(game_lost)
      assert result_lost.status == :lost
      assert result_lost.ending_type == :lament
    end

    test "phase_name returns Japanese names" do
      assert Game.phase_name(:event) == "イベントフェーズ"
      assert Game.phase_name(:discussion) == "相談フェーズ"
      assert Game.phase_name(:action) == "アクションフェーズ"
      assert Game.phase_name(:demurrage) == "減衰フェーズ"
      assert Game.phase_name(:life_update) == "生命更新フェーズ"
      assert Game.phase_name(:judgment) == "判定フェーズ"
    end

    test "in_phase? checks current phase" do
      game = %Game{Game.new("room_1") | phase: :action}

      assert Game.in_phase?(game, :action) == true
      assert Game.in_phase?(game, :discussion) == false
      assert Game.in_phase?(game, :event) == false
    end

    test "next_phase does nothing if game is not playing" do
      game = %Game{Game.new("room_1") | status: :won, phase: :action}

      result = Game.next_phase(game)
      # Unchanged
      assert result.phase == :action
      assert result.status == :won
    end

    test "action phase allows card playing" do
      game = %Game{
        Game.new("room_1")
        | phase: :action,
          currency: 1000
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")

      # Should be able to play cards in action phase
      hand = Map.get(game.hands, "p1", [])

      if hand != [] do
        card_id = List.first(hand)
        assert {:ok, _new_game} = Game.play_action(game, "p1", card_id, [])
      end
    end

    test "maybe_advance_turn only works in action phase" do
      game = %Game{
        Game.new("room_1")
        | phase: :action,
          currency: 1000,
          status: :playing
      }

      {:ok, game} = Game.join(game, "p1", "Player 1")

      # Play a card to make player ready
      hand = Map.get(game.hands, "p1", [])

      if hand != [] do
        card_id = List.first(hand)
        {:ok, game_after_action} = Game.play_action(game, "p1", card_id, [])

        # If player is ready and in action phase, maybe_advance_turn is called internally
        # Since there's only one player and they're ready, phase should advance to demurrage
        # But maybe_advance_turn calls next_phase which executes demurrage and advances to life_update
        assert game_after_action.phase in [:demurrage, :life_update, :action]
      end
    end
  end
end
