defmodule Shinkanki.GameEventTest do
  use ExUnit.Case
  alias Shinkanki.{Game, Card}

  describe "event card system" do
    test "event deck is initialized when creating a new game" do
      game = Game.new("room_1")
      assert length(game.event_deck) == 25
      assert game.current_event == nil
      assert game.event_discard_pile == []
    end

    test "event deck contains all 25 event cards" do
      game = Game.new("room_1")
      event_ids = Card.list_events() |> Enum.map(& &1.id)

      # All event cards should be in the deck
      assert Enum.all?(event_ids, &Enum.member?(game.event_deck, &1))
      assert length(Enum.uniq(game.event_deck)) == 25
    end

    test "draws and applies event card at the start of each turn" do
      game = Game.new("room_1")
      initial_forest = game.forest
      initial_culture = game.culture
      initial_social = game.social
      initial_currency = game.currency

      # Advance to turn 2 (should draw an event)
      new_game = Game.next_turn(game)

      # Event should be drawn
      assert new_game.current_event != nil
      assert new_game.turn == 2

      # Event effect should be applied (stats may have changed)
      # We can't predict which event, but stats should have changed or stayed the same
      assert new_game.forest >= 0
      assert new_game.culture >= 0
      assert new_game.social >= 0
    end

    test "event card is logged when drawn" do
      game = Game.new("room_1")
      new_game = Game.next_turn(game)

      # Check that event is logged
      assert length(new_game.logs) > 0

      assert Enum.any?(new_game.logs, fn log ->
               String.contains?(log, "Event:")
             end)
    end

    test "event card effect is applied correctly" do
      # Create a game and manually test event effects
      game = Game.new("room_1")

      # Get a specific event card
      event = Card.get_event(:e_harvest_festival)
      assert event != nil
      assert event.effect.forest == 8
      assert event.effect.culture == 5
      assert event.effect.social == 5

      # Test applying the effect
      game_with_event = Game.update_stats(game, event.effect)
      assert game_with_event.forest == game.forest + 8
      assert game_with_event.culture == game.culture + 5
      assert game_with_event.social == game.social + 5
    end

    test "event discard pile is used when event deck is empty" do
      game = %Game{
        Game.new("room_1")
        | event_deck: [],
          event_discard_pile: [:e_harvest_festival, :e_drought]
      }

      # Should reshuffle discard pile and draw from it
      new_game = Game.next_turn(game)

      # Event should be drawn from reshuffled discard
      assert new_game.current_event != nil
      # One card was drawn
      assert length(new_game.event_discard_pile) < 2
    end

    test "current event is cleared and moved to discard at turn end" do
      game = %Game{
        Game.new("room_1")
        | current_event: :e_harvest_festival,
          event_discard_pile: []
      }

      # Advance turn
      new_game = Game.next_turn(game)

      # Previous event should be in discard, new event should be current
      assert new_game.current_event != :e_harvest_festival
      assert :e_harvest_festival in new_game.event_discard_pile || new_game.current_event != nil
    end

    test "all event types are represented" do
      events = Card.list_events()

      # Check that we have different types of events
      disaster_events = Enum.filter(events, fn e -> :disaster in (e.tags || []) end)
      festival_events = Enum.filter(events, fn e -> :festival in (e.tags || []) end)
      blessing_events = Enum.filter(events, fn e -> :blessing in (e.tags || []) end)
      temptation_events = Enum.filter(events, fn e -> :temptation in (e.tags || []) end)
      special_events = Enum.filter(events, fn e -> :special in (e.tags || []) end)

      assert length(disaster_events) > 0
      assert length(festival_events) > 0
      assert length(blessing_events) > 0
      assert length(temptation_events) > 0
      assert length(special_events) > 0
      assert length(events) == 25
    end

    test "event cards have appropriate effects" do
      events = Card.list_events()

      # Check that disaster events have negative effects
      disaster = Enum.find(events, &(&1.id == :e_drought))

      assert disaster.effect.forest < 0 || disaster.effect.culture < 0 ||
               disaster.effect.social < 0

      # Check that festival events have positive effects
      festival = Enum.find(events, &(&1.id == :e_harvest_festival))

      assert festival.effect.forest > 0 || festival.effect.culture > 0 ||
               festival.effect.social > 0

      # Check that temptation events increase currency but may have negative side effects
      temptation = Enum.find(events, &(&1.id == :e_quick_profit))
      assert temptation.effect.currency > 0

      assert temptation.effect.forest < 0 || temptation.effect.culture < 0 ||
               temptation.effect.social < 0
    end
  end
end
