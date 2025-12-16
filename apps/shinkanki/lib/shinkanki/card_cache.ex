defmodule Shinkanki.CardCache do
  @moduledoc """
  ActionCard, EventCard, TalentCardをETSでキャッシュ
  アプリ起動時に一度だけDBから読み込み、以降はメモリから高速に取得
  """
  use GenServer

  require Logger

  @table_name :card_cache

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  指定IDのActionCardを取得
  """
  def get_action_card(id) when is_integer(id) do
    get(:action_cards, id)
  end

  def get_action_card(_), do: nil

  @doc """
  指定IDのEventCardを取得
  """
  def get_event_card(id) when is_integer(id) do
    get(:event_cards, id)
  end

  def get_event_card(_), do: nil

  @doc """
  指定IDのTalentCardを取得
  """
  def get_talent_card(id) when is_integer(id) do
    get(:talent_cards, id)
  end

  def get_talent_card(_), do: nil

  @doc """
  全ActionCardを取得
  """
  def all_action_cards do
    get_all(:action_cards)
  end

  @doc """
  全EventCardを取得
  """
  def all_event_cards do
    get_all(:event_cards)
  end

  @doc """
  全TalentCardを取得
  """
  def all_talent_cards do
    get_all(:talent_cards)
  end

  @doc """
  指定されたIDリストに含まれるActionCardのみを取得
  """
  def action_cards_by_ids(ids) when is_list(ids) do
    id_set = MapSet.new(ids)

    all_action_cards()
    |> Enum.filter(&MapSet.member?(id_set, &1.id))
  end

  def action_cards_by_ids(_), do: []

  @doc """
  キャッシュを再読み込み（カードデータ更新時に使用）
  """
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # ETSテーブルを作成
    :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])

    # Repoが利用可能な場合のみカードデータをロード
    if repo_available?() do
      load_cards()
    else
      Logger.warning("CardCache: Repo not available, cards will be loaded on first access")
    end

    {:ok, %{}}
  end

  defp repo_available? do
    try do
      Process.whereis(Shinkanki.Repo) != nil
    rescue
      _ -> false
    end
  end

  @impl true
  def handle_call(:reload, _from, state) do
    :ets.delete_all_objects(@table_name)
    count = load_cards()
    {:reply, {:ok, count}, state}
  end

  ## Private Functions

  defp get(type, id) do
    ensure_loaded()

    case :ets.lookup(@table_name, {type, id}) do
      [{{^type, ^id}, card}] -> card
      [] -> nil
    end
  end

  defp get_all(type) do
    ensure_loaded()

    :ets.match_object(@table_name, {{type, :_}, :_})
    |> Enum.map(fn {_, card} -> card end)
  end

  # キャッシュが空の場合、遅延ロードを試みる
  defp ensure_loaded do
    if :ets.info(@table_name, :size) == 0 and repo_available?() do
      load_cards()
    end
  end

  defp load_cards do
    action_count = load_action_cards()
    event_count = load_event_cards()
    talent_count = load_talent_cards()

    total = action_count + event_count + talent_count
    Logger.info("CardCache: Loaded #{total} cards (Action: #{action_count}, Event: #{event_count}, Talent: #{talent_count})")

    total
  end

  defp load_action_cards do
    cards = Shinkanki.Repo.all(Shinkanki.Games.ActionCard)

    Enum.each(cards, fn card ->
      :ets.insert(@table_name, {{:action_cards, card.id}, card})
    end)

    length(cards)
  end

  defp load_event_cards do
    cards = Shinkanki.Repo.all(Shinkanki.Games.EventCard)

    Enum.each(cards, fn card ->
      :ets.insert(@table_name, {{:event_cards, card.id}, card})
    end)

    length(cards)
  end

  defp load_talent_cards do
    cards = Shinkanki.Repo.all(Shinkanki.Games.TalentCard)

    Enum.each(cards, fn card ->
      :ets.insert(@table_name, {{:talent_cards, card.id}, card})
    end)

    length(cards)
  end
end
