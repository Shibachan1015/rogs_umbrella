defmodule Shinkanki.Types do
  @moduledoc """
  ゲーム全体で使用する型定義。
  Dialyzerによる静的型解析で参照される。
  """

  # ID型
  @type user_id :: binary()
  @type game_session_id :: binary()
  @type player_id :: binary()
  @type card_id :: integer() | binary()

  # ゲームパラメータ型
  @type parameter :: 0..100
  @type turn :: 1..20
  @type akasha :: non_neg_integer()
  @type life_index :: integer()

  # 列挙型
  @type role :: :dragon | :phoenix | :turtle | :tiger
  @type phase :: :dawn | :action | :dusk | :night | :hitoyo
  @type policy :: :balance | :forest | :culture | :social
  @type game_status :: :active | :completed | :failed

  # カード関連
  @type card_type :: :action | :event | :renkei
  @type card_effect :: %{
          optional(:forest) => integer(),
          optional(:culture) => integer(),
          optional(:social) => integer(),
          optional(:life_index) => integer(),
          optional(:akasha) => integer()
        }
end
