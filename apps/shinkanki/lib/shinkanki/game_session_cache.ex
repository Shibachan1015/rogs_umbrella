defmodule Shinkanki.GameSessionCache do
  @moduledoc """
  Cachex-based cache for game sessions to reduce database load.

  Caches active game sessions with automatic TTL expiration.
  Falls back to no-op when cache is not started (e.g., in test environment).
  """

  @cache_name :game_sessions_cache
  # 5 minutes TTL
  @default_ttl :timer.minutes(5)

  @doc """
  Returns the cache name for supervisor configuration.
  """
  def cache_name, do: @cache_name

  @doc """
  Checks if the cache is enabled.
  """
  def enabled? do
    Application.get_env(:shinkanki, :start_game_session_cache, true)
  end

  @doc """
  Gets a cached game session by ID.
  Returns `{:ok, game_session}` if cached, `:not_found` otherwise.
  """
  def get(id) do
    if enabled?() do
      case Cachex.get(@cache_name, id) do
        {:ok, nil} -> :not_found
        {:ok, game_session} -> {:ok, game_session}
        {:error, _reason} -> :not_found
      end
    else
      :not_found
    end
  end

  @doc """
  Caches a game session.
  """
  def put(game_session) do
    if enabled?() do
      Cachex.put(@cache_name, game_session.id, game_session, ttl: @default_ttl)
    else
      {:ok, true}
    end
  end

  @doc """
  Invalidates cache for a game session.
  Should be called when the game session is updated.
  """
  def invalidate(id) do
    if enabled?() do
      Cachex.del(@cache_name, id)
    else
      {:ok, true}
    end
  end

  @doc """
  Clears all cached data.
  """
  def clear do
    if enabled?() do
      Cachex.clear(@cache_name)
    else
      {:ok, 0}
    end
  end

  @doc """
  Returns cache statistics.
  """
  def stats do
    if enabled?() do
      Cachex.stats(@cache_name)
    else
      {:ok, %{}}
    end
  end
end
