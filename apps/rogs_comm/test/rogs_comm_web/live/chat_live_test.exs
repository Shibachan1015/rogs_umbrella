defmodule RogsCommWeb.ChatLiveTest do
  use RogsCommWeb.LiveViewCase

  import RogsComm.MessagesFixtures

  describe "Chat Live" do
    test "displays room information and messages", %{conn: conn} do
      room = room_fixture()
      message = message_fixture(%{room_id: room.id, content: "Hello, world!"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      assert render(view) =~ room.name
      assert render(view) =~ message.content
    end

    test "sends a message", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      view
      |> form("#chat-form", %{content: "Test message"})
      |> render_submit()

      assert render(view) =~ "Test message"
    end

    test "does not send empty message", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Count messages before submitting empty message
      html_before = render(view)
      message_count_before = length(String.split(html_before, "message-")) - 1

      view
      |> form("#chat-form", %{content: ""})
      |> render_submit()

      # Message count should not increase
      html_after = render(view)
      message_count_after = length(String.split(html_after, "message-")) - 1

      assert message_count_after == message_count_before
    end

    test "redirects when room not found", %{conn: conn} do
      invalid_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/rooms/#{invalid_id}/chat")
    end

    test "displays online users in presence list", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Presence list should be displayed (even if empty)
      assert render(view) =~ "Online"
    end

    test "updates display name", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      view
      |> form("#display-name-form", %{display_name: "New Name"})
      |> render_submit()

      assert render(view) =~ "New Name"
    end
  end
end
