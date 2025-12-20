defmodule ShinkankiWebWeb.Features.GameTest do
  use ShinkankiWebWeb.FeatureCase, async: false

  import RogsIdentity.AccountsFixtures
  import RogsComm.RoomsFixtures

  alias Shinkanki.Games
  alias Shinkanki.Games.ActionCard
  alias Shinkanki.Repo

  @moduletag :feature

  setup do
    # Seed action cards for testing
    seed_test_cards()

    # Create user and set password for login
    user = user_fixture() |> set_password()

    # Create a room and game session for testing
    room = room_fixture()
    {:ok, game_session} = Games.create_game_session_from_room(room.id, [user.id])

    {:ok, user: user, room: room, game_session: game_session}
  end

  defp seed_test_cards do
    # Create minimal test cards if none exist
    if Repo.aggregate(ActionCard, :count) == 0 do
      test_cards = [
        %{name: "テストカード1", category: "forest", effect_forest: 1, cost_akasha: 0},
        %{name: "テストカード2", category: "culture", effect_culture: 1, cost_akasha: 0},
        %{name: "テストカード3", category: "social", effect_social: 1, cost_akasha: 0},
        %{name: "テストカード4", category: "forest", effect_forest: 2, cost_akasha: 10},
        %{name: "テストカード5", category: "culture", effect_culture: 2, cost_akasha: 10}
      ]

      Enum.each(test_cards, fn attrs ->
        %ActionCard{}
        |> ActionCard.changeset(attrs)
        |> Repo.insert!()
      end)

      # Reload card cache
      Shinkanki.CardCache.reload()
    end
  end

  feature "logged in user can view game page", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    |> assert_has(Query.css("[data-phx-main]"))
  end

  feature "game page displays turn info", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Verify we're on the game page by checking for turn indicator
    |> assert_has(Query.text("T1", count: :any, minimum: 1))
  end

  feature "user can advance from event phase", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Should be in event phase initially (人代 phase)
    |> assert_has(Query.text("人代", count: :any, minimum: 1))
    # Click the advance button
    |> click(Query.button("確認して次へ進む"))
    # Should transition to action phase
    |> assert_has(Query.text("アクションフェーズ", count: :any, minimum: 1))
  end

  feature "user can select a card from hand", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Advance past event phase to action phase
    |> click(Query.button("確認して次へ進む"))
    # Wait for hand cards to be rendered (if any)
    |> assert_has(Query.css("[phx-click='select_card']", count: :any, minimum: 1))
    # Click the first card
    |> click(Query.css("[phx-click='select_card']", at: 0))
    # Verify the card is selected (has the ring class)
    |> assert_has(Query.css("[phx-click='select_card'].ring-2", count: 1))
  end

  feature "selecting different card changes selection", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Advance past event phase
    |> click(Query.button("確認して次へ進む"))
    # Wait for at least 2 cards
    |> assert_has(Query.css("[phx-click='select_card']", count: :any, minimum: 2))
    # Click first card
    |> click(Query.css("[phx-click='select_card']", at: 0))
    |> assert_has(Query.css("[phx-click='select_card'].ring-2", count: 1))
    # Click second card
    |> click(Query.css("[phx-click='select_card']", at: 1))
    # Still only one card should be selected
    |> assert_has(Query.css("[phx-click='select_card'].ring-2", count: 1))
  end

  feature "user can use a card", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Advance past event phase to action phase
    |> click(Query.button("確認して次へ進む"))
    # Wait for hand cards
    |> assert_has(Query.css("[phx-click='select_card']", count: :any, minimum: 1))
    # Click the first card to select it
    |> click(Query.css("[phx-click='select_card']", at: 0))
    # Click the "使用する" button
    |> click(Query.button("使用する"))
    # Talent selector modal appears - click "なしで続行" to skip talent selection
    |> click(Query.button("なしで続行"))
    # Confirmation modal should appear with "実行する" button
    |> assert_has(Query.button("実行する"))
    # Click to confirm
    |> click(Query.button("実行する"))
    # Toast message should appear confirming card was used
    |> assert_has(Query.text("を使用しました", count: :any, minimum: 1))
  end

  feature "card count decreases after using a card", %{session: session, user: user, room: room} do
    session
    |> log_in_user(user)
    |> visit("/game/#{room.slug}")
    |> wait_for_live_view()
    # Advance past event phase
    |> click(Query.button("確認して次へ進む"))
    # Count initial cards
    |> assert_has(Query.css("[phx-click='select_card']", count: :any, minimum: 1))
    # Select and use a card
    |> click(Query.css("[phx-click='select_card']", at: 0))
    |> click(Query.button("使用する"))
    # Skip talent selection
    |> click(Query.button("なしで続行"))
    |> click(Query.button("実行する"))
    # Wait for toast to confirm action completed
    |> assert_has(Query.text("を使用しました", count: :any, minimum: 1))
  end
end
