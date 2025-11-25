defmodule RogsComm.Cache.MessageCacheTest do
  use ExUnit.Case, async: false

  alias RogsComm.Cache.MessageCache

  setup do
    # Clear cache before each test
    MessageCache.clear()
    :ok
  end

  describe "get/1 and put/2" do
    test "returns :not_found when cache is empty" do
      assert MessageCache.get("room-1") == :not_found
    end

    test "stores and retrieves messages" do
      room_id = "room-1"
      messages = [
        %{id: "msg-1", content: "Hello"},
        %{id: "msg-2", content: "World"}
      ]

      MessageCache.put(room_id, messages)

      assert MessageCache.get(room_id) == {:ok, messages}
    end

    test "limits cache size to max_cache_size" do
      room_id = "room-1"
      # Create more messages than max_cache_size (100)
      messages = for i <- 1..150, do: %{id: "msg-#{i}", content: "Message #{i}"}

      MessageCache.put(room_id, messages)

      {:ok, cached} = MessageCache.get(room_id)
      assert length(cached) == 100
    end
  end

  describe "invalidate/1" do
    test "removes cached messages for a room" do
      room_id = "room-1"
      messages = [%{id: "msg-1", content: "Hello"}]

      MessageCache.put(room_id, messages)
      assert MessageCache.get(room_id) == {:ok, messages}

      MessageCache.invalidate(room_id)
      assert MessageCache.get(room_id) == :not_found
    end

    test "does not affect other rooms" do
      room1_id = "room-1"
      room2_id = "room-2"
      messages1 = [%{id: "msg-1", content: "Hello"}]
      messages2 = [%{id: "msg-2", content: "World"}]

      MessageCache.put(room1_id, messages1)
      MessageCache.put(room2_id, messages2)

      MessageCache.invalidate(room1_id)

      assert MessageCache.get(room1_id) == :not_found
      assert MessageCache.get(room2_id) == {:ok, messages2}
    end
  end

  describe "clear/0" do
    test "removes all cached data" do
      room1_id = "room-1"
      room2_id = "room-2"
      messages1 = [%{id: "msg-1", content: "Hello"}]
      messages2 = [%{id: "msg-2", content: "World"}]

      MessageCache.put(room1_id, messages1)
      MessageCache.put(room2_id, messages2)

      MessageCache.clear()

      assert MessageCache.get(room1_id) == :not_found
      assert MessageCache.get(room2_id) == :not_found
    end
  end
end

