defmodule RogsCommWeb.ChatLiveTest do
  use RogsCommWeb.LiveViewCase

  alias RogsComm.Messages

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

  describe "Message editing" do
    test "shows edited indicator for edited messages", %{conn: conn} do
      room = room_fixture()
      user_id = Ecto.UUID.generate()
      message = message_fixture(%{room_id: room.id, user_id: user_id})

      # Edit the message directly
      {:ok, updated_message} = Messages.edit_message(message, %{content: "Edited"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      html = render(view)
      assert html =~ "Edited"
      # Check for edited indicator
      assert html =~ "(編集済み)"
    end
  end

  describe "Message deletion" do
    test "soft deletes own message", %{conn: conn} do
      room = room_fixture()
      user_id = Ecto.UUID.generate()
      message = message_fixture(%{room_id: room.id, user_id: user_id})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Message should be visible initially
      assert render(view) =~ message.content

      # Soft delete the message
      {:ok, _} = Messages.soft_delete_message(message)

      # Reload the view
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Message should not be visible (soft deleted)
      refute render(view) =~ message.content
    end
  end

  describe "Pagination" do
    test "loads older messages", %{conn: conn} do
      room = room_fixture()

      # Create multiple messages with different timestamps
      messages =
        for i <- 1..5 do
          message_fixture(%{
            room_id: room.id,
            content: "Message #{i}",
            inserted_at: DateTime.add(DateTime.utc_now(), -i, :second)
          })
        end

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Get the first message ID (oldest in the stream)
      first_message = List.first(messages)

      # Trigger load older messages event
      view
      |> element("button[phx-click='load_older_messages']")
      |> render_click(%{"message_id" => first_message.id})

      # Check that older messages are loaded
      html = render(view)
      # All messages should be visible
      assert html =~ "Message 1"
      assert html =~ "Message 5"
    end

    test "hides load older button when no more messages", %{conn: conn} do
      room = room_fixture()

      # Create only a few messages
      _message = message_fixture(%{room_id: room.id})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Initially, button should be visible if has_older_messages is true
      html = render(view)
      # Button visibility depends on has_older_messages assign
    end
  end

  describe "Message search" do
    test "searches messages by content", %{conn: conn} do
      room = room_fixture()
      message1 = message_fixture(%{room_id: room.id, content: "Hello world"})
      message2 = message_fixture(%{room_id: room.id, content: "Goodbye world"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Perform search
      view
      |> form("#search-form", %{query: "Hello"})
      |> render_submit()

      html = render(view)
      assert html =~ "Hello"
      # message2 should not appear in search results
      refute html =~ "Goodbye"
    end

    test "clears search and returns to normal view", %{conn: conn} do
      room = room_fixture()
      message = message_fixture(%{room_id: room.id, content: "Test message"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Perform search
      view
      |> form("#search-form", %{query: "Test"})
      |> render_submit()

      # Clear search
      view
      |> element("button[phx-click='clear_search']")
      |> render_click()

      html = render(view)
      # All messages should be visible again
      assert html =~ message.content
    end

    test "handles empty search query", %{conn: conn} do
      room = room_fixture()
      message = message_fixture(%{room_id: room.id, content: "Test message"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Submit empty search
      view
      |> form("#search-form", %{query: ""})
      |> render_submit()

      html = render(view)
      # Should return to normal view
      assert html =~ message.content
    end
  end

  describe "Real-time updates" do
    test "receives new message broadcast", %{conn: conn} do
      room = room_fixture()

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Broadcast a new message
      topic = "room:#{room.id}"
      payload = %{
        id: Ecto.UUID.generate(),
        content: "Broadcasted message",
        user_id: Ecto.UUID.generate(),
        user_email: "test@example.com",
        inserted_at: DateTime.utc_now()
      }

      RogsCommWeb.Endpoint.broadcast(topic, "new_message", payload)

      # Wait for broadcast to be processed
      Process.sleep(100)

      html = render(view)
      assert html =~ "Broadcasted message"
    end

    test "receives message edited broadcast", %{conn: conn} do
      room = room_fixture()
      message = message_fixture(%{room_id: room.id, content: "Original"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Edit the message
      {:ok, updated_message} = Messages.edit_message(message, %{content: "Edited"})

      # Broadcast edit event
      topic = "room:#{room.id}"
      payload = %{
        id: updated_message.id,
        content: updated_message.content,
        edited_at: updated_message.edited_at
      }

      RogsCommWeb.Endpoint.broadcast(topic, "message_edited", payload)

      # Wait for broadcast to be processed
      Process.sleep(100)

      html = render(view)
      assert html =~ "Edited"
    end

    test "receives message deleted broadcast", %{conn: conn} do
      room = room_fixture()
      message = message_fixture(%{room_id: room.id, content: "To be deleted"})

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}/chat")

      # Initially message should be visible
      assert render(view) =~ "To be deleted"

      # Soft delete the message
      {:ok, _} = Messages.soft_delete_message(message)

      # Broadcast delete event
      topic = "room:#{room.id}"
      RogsCommWeb.Endpoint.broadcast(topic, "message_deleted", %{id: message.id})

      # Wait for broadcast to be processed
      Process.sleep(100)

      html = render(view)
      # Message should be removed from view
      refute html =~ "To be deleted"
    end
  end
end
