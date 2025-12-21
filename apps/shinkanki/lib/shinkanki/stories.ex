defmodule Shinkanki.Stories do
  @moduledoc """
  The Stories context.
  Handles story sections for the wiki-like story page.
  """

  import Ecto.Query, warn: false
  alias Shinkanki.Repo
  alias Shinkanki.Stories.StorySection
  alias Shinkanki.Stories.StorySectionHistory

  @doc """
  Returns all story sections ordered by order_index.
  """
  def list_sections do
    from(s in StorySection, order_by: [asc: s.order_index])
    |> Repo.all()
  end

  @doc """
  Gets a single story section by section_id.
  """
  def get_section(section_id) do
    Repo.get_by(StorySection, section_id: section_id)
  end

  @doc """
  Gets a single story section by id.
  """
  def get_section_by_id(id) do
    Repo.get(StorySection, id)
  end

  @doc """
  Creates a story section.
  """
  def create_section(attrs \\ %{}) do
    %StorySection{}
    |> StorySection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a story section with history tracking.
  Saves the current version to history before updating.
  """
  def update_section(%StorySection{} = section, attrs) do
    Repo.transaction(fn ->
      # Save current version to history
      history_attrs = %{
        story_section_id: section.id,
        section_id: section.section_id,
        title: section.title,
        content: section.content,
        version: section.version,
        updated_by: section.updated_by
      }

      %StorySectionHistory{}
      |> StorySectionHistory.changeset(history_attrs)
      |> Repo.insert!()

      # Update section with new version
      new_version = section.version + 1

      section
      |> StorySection.changeset(Map.put(attrs, :version, new_version))
      |> Repo.update!()
    end)
  end

  @doc """
  Gets the history of a story section.
  """
  def get_section_history(section_id) do
    from(h in StorySectionHistory,
      where: h.section_id == ^section_id,
      order_by: [desc: h.version]
    )
    |> Repo.all()
  end

  @doc """
  Gets a specific version from history.
  """
  def get_history_version(section_id, version) do
    Repo.get_by(StorySectionHistory, section_id: section_id, version: version)
  end

  @doc """
  Rollback a section to a specific version.
  """
  def rollback_section(section_id, version, user_id \\ nil) do
    with section when not is_nil(section) <- get_section(section_id),
         history when not is_nil(history) <- get_history_version(section_id, version) do
      update_section(section, %{
        title: history.title,
        content: history.content,
        updated_by: user_id
      })
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Deletes a story section.
  """
  def delete_section(%StorySection{} = section) do
    Repo.delete(section)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story section changes.
  """
  def change_section(%StorySection{} = section, attrs \\ %{}) do
    StorySection.changeset(section, attrs)
  end

  @doc """
  Seeds the initial story content if the table is empty.
  """
  def seed_initial_content do
    if Repo.aggregate(StorySection, :count, :id) == 0 do
      initial_sections()
      |> Enum.with_index()
      |> Enum.each(fn {{section_id, title, content}, index} ->
        create_section(%{
          section_id: section_id,
          title: title,
          content: content,
          order_index: index
        })
      end)
    end
  end

  defp initial_sections do
    [
      {"prologue", "序章：忘れられた神性",
       """
       神環記の舞台は、2038 年の近未来。かつて豊かだった森と文化は荒れ、コミュニティは分断されました。
       人々は「自分の頭で考えること」をやめ、巨大な仕組みに委ねてしまったのです。
       その隙を突いて八岐大蛇（やまたのおろち）が覚醒し、世界中に邪気をばら撒きました。

       しかし神々は諦めません。人間の中に眠る **神性（カミゴコロ）** を信じ、20 年間の
       「試練」としてこのゲームを与えました。プレイヤーはそれぞれの才能を持つ "分霊" として地上に降り、
       森・文化・絆を取り戻す物語を紡ぎます。
       """},
      {"orochi", "八岐大蛇と邪気",
       """
       - 邪気は人の怠慢と恐れが生み出す黒い霧。レベル 8 で八岐大蛇が完全体となります。
       - 目覚めた八岐大蛇は、人を「便利な端末」に変えてしまう。自分で考えず、命を削る指示に従うだけの存在へ。
       - プレイヤーが森・文化・コミュニティを育てると霧が晴れ、反対に無視すると更なる覚醒（Lv1→Lv3）が進み、翌年のスタート時にペナルティが降りかかります。
       """},
      {"roles", "四人の役割",
       """
       それぞれの役割は、神々が選んだ「現代の神職」です。職能は違っても目的はひとつ。
       **人が自分の頭で考え、手を動かし、命の循環を取り戻すこと** にあります。

       1. **森守（Forest Guardian）** – 土地と命の循環を守る。木を植えるだけでなく、祈りの営みを取り戻す。
       2. **文化織り（Heritage Weaver）** – 詩や歌、記録を通じて人の誇りを蘇らせる。
       3. **絆結び（Community Keeper）** – 断たれた家族や地域を再び結び、共に動く場を作る。
       4. **空環設計士（Akasha Architect）** – 空環（くうかん）と呼ばれる通貨を循環させ、滞りを祓う。
       """},
      {"journey", "20年の旅路",
       """
       一年は「人代 → 神議り → 営み → 呼吸 → 結び → 年送り」という 6 フェーズで進みます。
       人代で現実の荒波を受け、神議りで方針を決め、営みでカードを選び、
       呼吸で空環を還し、結びで学びを振り返る。そして年送りで邪気と向き合う。

       20 年後、森・文化・絆の合計が 40 に届けば「神々の祝福」。
       20 に満たなければ、世界は「神々の嘆き」としてリセットされます。
       たとえ失敗しても記録（ログ）に学びが残り、次の挑戦者へ物語が継承されます。
       """},
      {"divine_work", "人が担う「神の仕事」",
       """
       - 文化を守り、子どもたちに伝える人を増やす。
       - 森、山、海、川、植物、動物を尊び、循環に参加する。
       - 空環（Akasha）を偏りなく還流させ、貯め込まない。
       - 自分の頭で考え、他者と対話し、八岐大蛇の囁きを祓う。

       これらはすべて「神様の下請け」ではなく、人が本来持っていた神性を思い出す行為です。
       ゲームを遊ぶたびに、プレイヤー自身がその感覚を掴めるようデザインされています。
       """},
      {"future", "未来への灯",
       """
       物語篇は今後もアップデートを続けます。プレイヤーの記録や、実際の地域づくりから得た学びを反映し、
       version.2 以降では各地域の伝承や、新たな役割（旅人、祈り人など）も登場する予定です。

       あなたの 20 年が、次の挑戦者の物語を変えます。ようこそ神環記へ。
       """}
    ]
  end
end
