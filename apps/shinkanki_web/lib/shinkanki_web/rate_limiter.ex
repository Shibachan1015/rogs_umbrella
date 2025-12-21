defmodule ShinkankiWeb.RateLimiter do
  @moduledoc """
  シンプルなETSベースのレート制限
  スライディングウィンドウ方式で実装
  """
  use GenServer

  @table_name :rate_limiter
  @cleanup_interval :timer.minutes(5)

  # デフォルトのレート制限設定
  @default_limits %{
    # チャットメッセージ: 60秒で10回まで
    chat_message: {10, 60_000},
    # 認証試行: 60秒で5回まで
    auth_attempt: {5, 60_000},
    # API リクエスト: 60秒で100回まで
    api_request: {100, 60_000}
  }

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  レート制限をチェック
  - key: 制限対象のキー（例: "chat:user_123"）
  - action: アクションの種類（:chat_message, :auth_attempt, :api_request）

  戻り値:
  - {:allow, remaining} - 許可、残りリクエスト数
  - {:deny, retry_after_ms} - 拒否、リトライまでのミリ秒
  """
  def check_rate(key, action \\ :api_request) do
    {max_requests, window_ms} = Map.get(@default_limits, action, {100, 60_000})
    now = System.system_time(:millisecond)
    window_start = now - window_ms

    # 古いエントリを削除し、現在のウィンドウ内のリクエスト数をカウント
    case :ets.lookup(@table_name, key) do
      [] ->
        :ets.insert(@table_name, {key, [{now, 1}]})
        {:allow, max_requests - 1}

      [{^key, timestamps}] ->
        # ウィンドウ内のタイムスタンプのみを保持
        valid_timestamps = Enum.filter(timestamps, fn {ts, _} -> ts > window_start end)
        count = Enum.reduce(valid_timestamps, 0, fn {_, c}, acc -> acc + c end)

        if count < max_requests do
          new_timestamps = [{now, 1} | valid_timestamps]
          :ets.insert(@table_name, {key, new_timestamps})
          {:allow, max_requests - count - 1}
        else
          # 最も古いタイムスタンプからリトライ時間を計算
          oldest = valid_timestamps |> Enum.map(fn {ts, _} -> ts end) |> Enum.min()
          retry_after = oldest + window_ms - now
          {:deny, max(retry_after, 0)}
        end
    end
  end

  @doc """
  特定のキーのレート制限をリセット
  """
  def reset(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_entries do
    now = System.system_time(:millisecond)
    # 最大ウィンドウサイズ（60秒）より古いエントリを削除
    max_window = 60_000

    :ets.foldl(
      fn {key, timestamps}, acc ->
        valid = Enum.filter(timestamps, fn {ts, _} -> ts > now - max_window end)

        if Enum.empty?(valid) do
          :ets.delete(@table_name, key)
        else
          :ets.insert(@table_name, {key, valid})
        end

        acc
      end,
      nil,
      @table_name
    )
  end
end
