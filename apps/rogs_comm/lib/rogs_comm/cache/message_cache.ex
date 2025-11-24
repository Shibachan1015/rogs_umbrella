defmodule RogsComm.Cache.MessageCache do
  @moduledoc """
  GenServer-based cache for room messages to reduce database load.

  Caches the most recent messages per room with TTL-based invalidation.
  """

  use GenServer

  require Logger

  # 5 minutes in milliseconds
  @default_ttl 300_000
  # Maximum messages per room
  @max_cache_size 100

  ## Client API

  @doc """
  Starts the message cache server.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets cached messages for a room.
  Returns `{:ok, messages}` if cached, `:not_found` otherwise.
  """
  def get(room_id) do
    GenServer.call(__MODULE__, {:get, room_id})
  end

  @doc """
  Caches messages for a room.
  """
  def put(room_id, messages) when is_list(messages) do
    GenServer.cast(__MODULE__, {:put, room_id, messages})
  end

  @doc """
  Invalidates cache for a room (e.g., when a new message is added).
  """
  def invalidate(room_id) do
    GenServer.cast(__MODULE__, {:invalidate, room_id})
  end

  @doc """
  Clears all cached data.
  """
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, room_id}, _from, state) do
    case Map.get(state, room_id) do
      nil ->
        {:reply, :not_found, state}

      {messages, _timestamp} ->
        {:reply, {:ok, messages}, state}
    end
  end

  @impl true
  def handle_cast({:put, room_id, messages}, state) do
    # Limit cache size
    cached_messages = Enum.take(messages, @max_cache_size)
    timestamp = System.monotonic_time(:millisecond)

    new_state = Map.put(state, room_id, {cached_messages, timestamp})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:invalidate, room_id}, state) do
    new_state = Map.delete(state, room_id)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    new_state =
      Enum.reduce(state, %{}, fn {room_id, {messages, timestamp}}, acc ->
        if now - timestamp < @default_ttl do
          Map.put(acc, room_id, {messages, timestamp})
        else
          acc
        end
      end)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, new_state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @default_ttl)
  end
end
