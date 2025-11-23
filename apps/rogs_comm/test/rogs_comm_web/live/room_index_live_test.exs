defmodule RogsCommWeb.RoomIndexLiveTest do
  use RogsCommWeb.LiveViewCase

  describe "Room Index" do
    test "displays list of public rooms", %{conn: conn} do
      public_room = room_fixture(%{name: "Public Room", is_private: false})
      _private_room = room_fixture(%{name: "Private Room", is_private: true})

      {:ok, view, _html} = live(conn, ~p"/rooms")

      assert has_element?(view, "h1", "チャットルーム")
      assert render(view) =~ public_room.name
      refute render(view) =~ "Private Room"
    end

    test "creates a new room with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/rooms")

      view
      |> form("#room-form", room: %{name: "New Room", topic: "A test room", is_private: false})
      |> render_submit()

      assert render(view) =~ "ルームを作成しました"
      assert render(view) =~ "New Room"
    end

    test "displays validation errors for invalid room data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/rooms")

      result =
        view
        |> form("#room-form", room: %{name: ""})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "navigates to chat page when clicking on a room", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms")

      assert view
             |> element("a[href='/rooms/#{room.id}/chat']")
             |> render_click()
             |> follow_redirect(conn, ~p"/rooms/#{room.id}/chat")
    end
  end
end
