defmodule RogsComm.RoomCleaner do
  @moduledoc """
  定期的にルームをクリーンアップするGenServer
  - 空きルーム（0人）: 10分後に削除
  - 無活動ルーム: 12時間後に削除
  """
  use GenServer
  require Logger

  alias RogsComm.Rooms

  # 1分ごとにチェック
  @check_interval :timer.minutes(1)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # 初回実行をスケジュール
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    perform_cleanup()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @check_interval)
  end

  defp perform_cleanup do
    # 空きルームの削除
    {empty_count, _} = Rooms.cleanup_empty_rooms()

    if empty_count > 0 do
      Logger.info("[RoomCleaner] Deleted #{empty_count} empty room(s)")
    end

    # 無活動ルームの削除
    {inactive_count, _} = Rooms.cleanup_inactive_rooms()

    if inactive_count > 0 do
      Logger.info("[RoomCleaner] Deleted #{inactive_count} inactive room(s)")
    end
  rescue
    error ->
      Logger.error("[RoomCleaner] Cleanup failed: #{inspect(error)}")
  end
end
