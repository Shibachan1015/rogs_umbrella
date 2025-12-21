defmodule Shinkanki.Rulebook do
  @moduledoc """
  The Rulebook context.
  Handles rulebook sections for the wiki-like rulebook page.
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo
  alias Shinkanki.Rulebook.RulebookSection
  alias Shinkanki.Rulebook.RulebookSectionHistory

  def list_sections do
    from(s in RulebookSection, order_by: [asc: s.order_index])
    |> Repo.all()
  end

  def get_section(section_id) do
    Repo.get_by(RulebookSection, section_id: section_id)
  end

  def get_section_by_id(id) do
    Repo.get(RulebookSection, id)
  end

  def create_section(attrs \\ %{}) do
    %RulebookSection{}
    |> RulebookSection.changeset(attrs)
    |> Repo.insert()
  end

  def update_section(%RulebookSection{} = section, attrs) do
    Repo.transaction(fn ->
      # Save current version to history
      history_attrs = %{
        rulebook_section_id: section.id,
        section_id: section.section_id,
        title: section.title,
        content: section.content,
        version: section.version,
        updated_by: section.updated_by,
        editor_name: section.editor_name
      }

      %RulebookSectionHistory{}
      |> RulebookSectionHistory.changeset(history_attrs)
      |> Repo.insert!()

      # Update section with new version
      new_version = section.version + 1

      section
      |> RulebookSection.changeset(Map.put(attrs, :version, new_version))
      |> Repo.update!()
    end)
  end

  def get_section_history(section_id) do
    from(h in RulebookSectionHistory,
      where: h.section_id == ^section_id,
      order_by: [desc: h.version]
    )
    |> Repo.all()
  end

  def get_history_version(section_id, version) do
    Repo.get_by(RulebookSectionHistory, section_id: section_id, version: version)
  end

  def rollback_section(section_id, version, user_id \\ nil, editor_name \\ nil) do
    with section when not is_nil(section) <- get_section(section_id),
         history when not is_nil(history) <- get_history_version(section_id, version) do
      update_section(section, %{
        title: history.title,
        content: history.content,
        updated_by: user_id,
        editor_name: editor_name || "ロールバック"
      })
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_section(%RulebookSection{} = section) do
    Repo.delete(section)
  end

  def change_section(%RulebookSection{} = section, attrs \\ %{}) do
    RulebookSection.changeset(section, attrs)
  end

  def seed_initial_content do
    if Repo.aggregate(RulebookSection, :count, :id) == 0 do
      initial_sections()
      |> Enum.with_index()
      |> Enum.each(fn {{section_id, title, content}, index} ->
        create_section(%{
          section_id: section_id,
          title: title,
          content: content,
          order_index: index,
          editor_name: "初期データ"
        })
      end)
    end
  end

  defp initial_sections do
    [
      {"overview", "1. ゲームの目的",
       """
       神環記は 1〜4 人協力型の長期キャンペーンです。プレイヤーは「森守」「文化織り」「絆結び」「空環設計士」として 20 年にわたる再生を指揮します。最終的に **L = F + K + S ≥ 40** を達成すれば「神々の祝福」エンディング、それ未満の場合は状況に応じた別エンディングになります。

       - 森（F）・文化（K）・絆（S）は 0〜10 のトラック。0 になると即敗北。
       - 空環（Akasha）は各プレイヤーが個別に所持。営みカードや連携で消費します。
       - 邪気トラック（0〜8）は八岐大蛇の覚醒を管理。Lv が上がるほどペナルティが強くなります。
       """},
      {"components", "2. コンポーネント",
       """
       - **メインボード**：F/K/S/邪気/年トラックを表示。
       - **人代（Hitoyo）カード**：毎年の荒波イベント。邪気に応じて 1〜3 枚引く。
       - **営み（Action）カード**：プレイヤーの主な行動。カテゴリ（森/文化/絆/空環）ごとに効果がある。
       - **才能カード**：プレイヤー固有のボーナス。アクションに合わせて同調すると威力アップ。
       - **連携（Renkei）カード**：複数人で協力して実行する特別プロジェクト。
       - **磨き（Migaki）カード**：一時的な強化や祓い。呼吸フェーズなどで使用。
       """},
      {"setup", "3. セットアップ",
       """
       1. 森・文化・絆をそれぞれ **3〜5 のランダム値** に設定。
       2. 邪気トラックは **Lv7**（八岐大蛇 Lv1）から開始。
       3. 各プレイヤーは役割を選び、初期空環 50〜100 を受け取る。
       4. 営みデッキをシャッフルして 5 枚を場に並べる。
       5. 年マーカーを 1/20 に置く。人代カード山札をセット。

       プロトタイプ UI では上記手順が自動で処理されます。
       """},
      {"year-flow", "4. 1年の流れ",
       """
       1. **人代** – 邪気に応じた人代カードを引き、世界への影響を適用する。
       2. **神議り** – 今年の方針（森/文化/絆/祓い）を共通で決める。
       3. **営み** – 各プレイヤーが順番に営みカードを 1 枚ずつ実行。1 ターンに行動できるのはこのフェーズのみ。
       4. **呼吸** – 空環の自動還流＋任意の還流。邪気を祓うチャンス。
       5. **結び** – その年の振り返りと称号確認。必要なら特殊イベントを解決。
       6. **年送り** – 邪気→八岐大蛇の処理、生命指数チェック、年カウンター +1。
       """},
      {"phases", "5. 各フェーズ詳細",
       """
       **5-1. 人代フェーズ**
       - 邪気0〜2: 1枚 / 3〜5: 2枚 / 6〜8: 3枚。
       - オロチ Lv によって効果倍率が変化（Lv1:+0、Lv2:+1 など）。
       - UI では「確認して次へ進む」で結果を適用。

       **5-2. 神議りフェーズ**
       方針ボタンから今年の重点を 1 つ選択。営みで方針と異なるカテゴリのカードを使うと邪気 +1。

       **5-3. 営み（アクション）フェーズ**
       - 順番に 1 枚ずつカードを使う。プレイヤー全員が「行動済み」になると自動で呼吸に移行。
       - 営みフェーズ以外ではカードを使用できない（UI にガードが追加されています）。
       - 才能を組み合わせると効果が +1/+2 される。

       **5-4. 呼吸フェーズ**
       - 空環 10P を還流すると、対象ステータス +1 / 邪気 -1。
       - 空環が 5 以上のプレイヤーは自動還流（1P）と邪気 -1 が発生。

       **5-5. 結びフェーズ**
       称号・称賛・プロジェクトの達成状況を確認。連携カードの効果もここでまとめて反映されます。

       **5-6. 年送りフェーズ**
       - 邪気が閾値（初期値 3）を超えていれば **八岐大蛇 Lv が +1**。
       - Lv1: 森 -1、Lv2: 文化 -1、Lv3: 絆 -1 のペナルティを次年開始時に適用。
       - 生命指数チェック → 勝利条件 or ゲーム継続。
       """},
      {"cards", "6. カードの種類と読み方",
       """
       **営みカード**
       - カテゴリアイコン（🌲/🎭/🤝/φ）とコストが表示される。
       - モバイル UI ではカードをタップ → 詳細画面から「このカードを使う」。
       - 「F:+2」などの表記はトラックを即時に増減させる。

       **連携カード**
       - 必要人数とコストがカードに記載されている。
       - 全員が参加するとボーナス効果（邪気抑制など）が発動。
       - 提案→参加→完了まで同じターン内で処理。

       **磨きカード**
       - 呼吸フェーズなどで使用できる一時効果。
       - 例：邪気-2、空環 +30、次の営みカードを無料にする など。
       """},
      {"orochi", "7. 邪気と八岐大蛇",
       """
       邪気トラックが **evil_threshold**（初期 3）を超えるたびに八岐大蛇の Lv が 1 上昇します。Lv3 で最大。Lv が上がると人代カードが厳しくなり、呼吸フェーズでの自動ペナルティが増大します。

       **祓いの手段**
       - 呼吸フェーズの還流で邪気 -1。
       - 営みカードや磨きカードの一部が「邪気 -X」を持つ。
       - 方針「祓い」を選ぶとその年の邪気増加が抑えられます。
       """},
      {"endings", "8. エンディング条件",
       """
       | いのち指数 L | エンディング |
       |-------------|-------------|
       | 40 以上 | 🌈 神々の祝福 |
       | 30〜39 | 🌿 浄化の兆し |
       | 20〜29 | 🌙 揺らぎの未来 |
       | 19 以下 or F/K/S いずれか 0 | 🔥 神々の嘆き |

       いのち指数が 20 未満でも、ログや物語データは次の挑戦者に受け継がれます。失敗が必ずしも徒労にならない設計になっている点が神環記の特徴です。
       """},
      {"appendix", "付録：UIガイドと略号表",
       """
       - **🐍 オロチ Lv**：ヘッダー右上に表示。Lv が上がると人代がより危険に。
       - **⏱ 自動進行タイマー**：各フェーズで残り時間を表示（デフォルト 5 分）。
       - **φ（空環）**：各プレイヤーが所持するローカル通貨。営み/連携のコストに使用。
       - **F/K/S**：森（Forest）/文化（Culture）/絆（Social）の略。

       さらに詳しいストーリー背景や設定は [物語篇](/story) を参照してください。
       """}
    ]
  end
end
