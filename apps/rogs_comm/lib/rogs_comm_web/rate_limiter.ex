defmodule RogsCommWeb.RateLimiter do
  @moduledoc """
  Simple rate limiter using ETS for in-memory tracking.
  Limits events per user per time window.
  """

  @table_name :rogs_comm_rate_limits
  @default_limit 5
  @default_window_seconds 1

  def init do
    :ets.new(@table_name, [:set, :public, :named_table])
  end

  @doc """
  Checks if an action is allowed for a user.
  Returns `{:ok, :allowed}` or `{:error, :rate_limited}`.
  """
  def check(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window_seconds = Keyword.get(opts, :window_seconds, @default_window_seconds)

    key = {user_id, trunc(:erlang.system_time(:second) / window_seconds)}

    case :ets.lookup(@table_name, key) do
      [] ->
        :ets.insert(@table_name, {key, 1})
        {:ok, :allowed}

      [{^key, count}] when count < limit ->
        :ets.update_counter(@table_name, key, 1)
        {:ok, :allowed}

      _ ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Clears rate limit entries older than the specified window.
  """
  def cleanup(window_seconds \\ @default_window_seconds) do
    current_window = trunc(:erlang.system_time(:second) / window_seconds)

    :ets.foldl(
      fn {key, _count}, acc ->
        {_user_id, window} = key

        if window < current_window - 1 do
          :ets.delete(@table_name, key)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
  end
end

