defmodule Shinkanki.Repo.Migrations.AddEvilAndOrochiSystem do
  use Ecto.Migration

  def change do
    # game_sessions テーブルに邪気・オロチ関連フィールドを追加
    alter table(:game_sessions) do
      # 邪気トラック (共有邪気プール)
      add :evil_pool, :integer, default: 0
      # 邪気がオロチに変換される閾値
      add :evil_threshold, :integer, default: 3
      # 八岐大蛇レベル (0-3)
      add :orochi_level, :integer, default: 0
      # 今年の方針 (神議りで決定)
      add :current_policy, :string
    end

    # players テーブルに個人邪気を追加
    alter table(:players) do
      # 個人邪気トークン
      add :evil_tokens, :integer, default: 0
      # 称号リスト (JSON配列)
      add :titles, {:array, :string}, default: []
    end

    # turn_states テーブルにフェーズを追加
    # 既存: event, action, dao, end
    # 新規: kami_hakari (神議り), breathing (呼吸), musuhi (結び)
    # フェーズ順序: kami_hakari -> event -> action -> breathing -> musuhi -> end

    # action_cards テーブルに邪気効果を追加
    alter table(:action_cards) do
      # このカードを使うと邪気が増減する量
      add :evil_delta, :integer, default: 0
      # 禊カードかどうか
      add :is_migaki, :boolean, default: false
    end

    # event_cards テーブルに邪気効果を追加
    alter table(:event_cards) do
      # このイベントで邪気が増減する量
      add :evil_delta, :integer, default: 0
    end
  end
end
