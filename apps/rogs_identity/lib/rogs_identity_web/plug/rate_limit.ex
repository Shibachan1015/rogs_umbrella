defmodule RogsIdentityWeb.Plug.RateLimit do
  @moduledoc """
  Rate limiting plug to prevent brute force attacks.

  Uses ETS table to track attempts per key (IP address, email, etc.)
  within a time window.

  ## Options

    * `:max_attempts` - Maximum number of attempts allowed (default: 5)
    * `:window_seconds` - Time window in seconds (default: 300 = 5 minutes)
    * `:key_type` - Type of key to use: `:login`, `:password_reset`, or `:ip` (default: `:ip`)
    * `:error_message` - Custom error message (optional)

  ## Examples

      plug RogsIdentityWeb.Plug.RateLimit,
        max_attempts: 5,
        window_seconds: 300,
        key_func: fn conn -> conn.remote_ip |> :inet.ntoa() |> to_string() end

  """

  import Plug.Conn
  import Phoenix.Controller

  @behaviour Plug

  @default_max_attempts 5
  @default_window_seconds 300

  def init(opts) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    window_seconds = Keyword.get(opts, :window_seconds, @default_window_seconds)
    key_type = Keyword.get(opts, :key_type, :ip)

    error_message =
      Keyword.get(
        opts,
        :error_message,
        "Torii security cooldown active. Please wait a moment before trying again."
      )

    %{
      max_attempts: max_attempts,
      window_seconds: window_seconds,
      key_type: key_type,
      error_message: error_message
    }
  end

  def call(conn, opts) do
    key = extract_key(conn, opts.key_type)

    case check_rate_limit(key, opts.max_attempts, opts.window_seconds) do
      :ok ->
        conn

      {:error, :rate_limit_exceeded} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: opts.error_message})
        |> halt()
    end
  end

  # Private functions

  defp extract_key(conn, :login) do
    case conn.body_params do
      %{"email" => email} when is_binary(email) -> "login:#{email}"
      %{"user" => %{"email" => email}} when is_binary(email) -> "login:#{email}"
      _ -> "login:#{ip_to_string(conn.remote_ip)}"
    end
  end

  defp extract_key(conn, :password_reset) do
    case conn.body_params do
      %{"user" => %{"email" => email}} when is_binary(email) -> "password_reset:#{email}"
      _ -> "password_reset:#{ip_to_string(conn.remote_ip)}"
    end
  end

  defp extract_key(conn, :ip) do
    ip_to_string(conn.remote_ip)
  end

  defp ip_to_string(ip) do
    case ip do
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
      {a, b, c, d, e, f, g, h} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
      _ -> "unknown"
    end
  end

  defp check_rate_limit(key, max_attempts, window_seconds) do
    table = get_or_create_table()
    now = System.system_time(:second)
    window_start = now - window_seconds

    # Clean old entries
    cleanup_old_entries(table, window_start)

    # Get current attempts
    attempts = get_attempts(table, key, window_start)

    if attempts >= max_attempts do
      {:error, :rate_limit_exceeded}
    else
      # Increment attempts
      record_attempt(table, key, now)
      :ok
    end
  end

  defp get_or_create_table do
    case :ets.whereis(:rate_limit_table) do
      :undefined ->
        :ets.new(:rate_limit_table, [:set, :public, :named_table])

      table ->
        table
    end
  end

  defp cleanup_old_entries(table, window_start) do
    # Clean up entries older than the window
    :ets.select_delete(table, [
      {{:"$1", :"$2"}, [{:<, :"$2", window_start}], [true]}
    ])
  end

  defp get_attempts(table, key, window_start) do
    case :ets.lookup(table, key) do
      [] ->
        0

      [{^key, timestamps}] ->
        Enum.count(timestamps, fn timestamp -> timestamp >= window_start end)
    end
  end

  defp record_attempt(table, key, timestamp) do
    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, [timestamp]})

      [{^key, timestamps}] ->
        # Keep only recent timestamps (within window)
        window_start = timestamp - 3600
        filtered_timestamps = Enum.filter(timestamps, fn ts -> ts >= window_start end)
        :ets.insert(table, {key, [timestamp | filtered_timestamps]})
    end
  end

  @doc """
  Resets the rate limit for a given key.
  Useful for testing or manual reset.
  """
  def reset(key) do
    case :ets.whereis(:rate_limit_table) do
      :undefined -> :ok
      table -> :ets.delete(table, key)
    end
  end

  @doc """
  Gets the current attempt count for a key.
  """
  def get_attempt_count(key, window_seconds \\ 300) do
    case :ets.whereis(:rate_limit_table) do
      :undefined ->
        0

      table ->
        now = System.system_time(:second)
        window_start = now - window_seconds
        get_attempts(table, key, window_start)
    end
  end
end
