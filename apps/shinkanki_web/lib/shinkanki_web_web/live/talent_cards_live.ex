defmodule ShinkankiWebWeb.TalentCardsLive do
  @moduledoc """
  TalentCards catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.TalentCard
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_talent_cards()

    socket =
      socket
      |> assign(:cards, cards)
      |> assign(:editing_card, nil)
      |> assign(:show_new_form, false)
      |> assign(:changeset, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("start_edit", %{"card-id" => card_id}, socket) do
    card = Cards.get_talent_card(card_id)

    if card do
      changeset = Cards.change_talent_card(card)

      {:noreply,
       socket
       |> assign(:editing_card, card_id)
       |> assign(:changeset, changeset)}
    else
      {:noreply, put_flash(socket, :error, "カードが見つかりません")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_card, nil)
     |> assign(:changeset, nil)}
  end

  @impl true
  def handle_event("save_edit", %{"talent_card" => params}, socket) do
    card = Cards.get_talent_card(socket.assigns.editing_card)
    params = process_compatible_tags(params)

    case Cards.update_talent_card(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_talent_cards()

        {:noreply,
         socket
         |> assign(:cards, cards)
         |> assign(:editing_card, nil)
         |> assign(:changeset, nil)
         |> put_flash(:info, "カードを更新しました")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, "保存に失敗しました")}
    end
  end

  @impl true
  def handle_event("start_new", _params, socket) do
    changeset = Cards.change_talent_card(%TalentCard{})

    {:noreply,
     socket
     |> assign(:show_new_form, true)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("cancel_new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_form, false)
     |> assign(:changeset, nil)}
  end

  @impl true
  def handle_event("create_card", %{"talent_card" => params}, socket) do
    params = process_compatible_tags(params)

    case Cards.create_talent_card(params) do
      {:ok, _card} ->
        cards = Cards.list_talent_cards()

        {:noreply,
         socket
         |> assign(:cards, cards)
         |> assign(:show_new_form, false)
         |> assign(:changeset, nil)
         |> put_flash(:info, "新しいカードを作成しました")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, "作成に失敗しました")}
    end
  end

  defp process_compatible_tags(params) do
    case Map.get(params, "compatible_tags") do
      nil -> params
      tags when is_binary(tags) ->
        tag_list = tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        Map.put(params, "compatible_tags", tag_list)
      _ -> params
    end
  end

  defp category_label("forest"), do: "🌲 森"
  defp category_label("culture"), do: "🎭 文化"
  defp category_label("social"), do: "🤝 絆"
  defp category_label("akasha"), do: "φ 空環"
  defp category_label("universal"), do: "🌈 万能"
  defp category_label(_), do: "その他"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="card-catalog talent-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>才能カード</h1>
        <p class="subtitle">Talent Cards</p>
        <p class="description">
          プレイヤーそれぞれの得意・役割・癖を表すカード。
          営みやみがきカードに重ねることで、その行動の効果を少しだけ強くします。
        </p>
        <div class="wiki-notice">
          <p>このページは誰でも編集できます。各カードの「編集」ボタンから内容を改善してください。</p>
        </div>
        <div class="wiki-actions">
          <button type="button" class="btn-add-section" phx-click="start_new">
            ＋ 新規カード追加
          </button>
        </div>
      </header>

      <nav class="catalog-nav">
        <a href="/rulebook">ルールブック</a>
        <a href="/cards/talent" class="active">才能</a>
        <a href="/cards/cocreation">共創</a>
        <a href="/cards/action">アクション</a>
        <a href="/cards/hitoyo">人代</a>
        <a href="/cards/migaki">磨き</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>才能カードとは</h2>
        <ul>
          <li>ゲーム開始時、各プレイヤーは才能カードを<strong>3枚引き</strong>、その中から<strong>1枚を選んで</strong>自分の前に置きます</li>
          <li>才能カードにはタグ（聴く、てしごと、育てる等）が書かれています</li>
          <li>アクションカードのタグと一致すれば、そのアクションに<strong>+1ボーナス</strong>を与えられます</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>才能カード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card talent-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="talent_card[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>カテゴリ</label>
                  <select name="talent_card[category]">
                    <option value="forest" selected={@changeset.data.category == "forest"}>🌲 森</option>
                    <option value="culture" selected={@changeset.data.category == "culture"}>🎭 文化</option>
                    <option value="social" selected={@changeset.data.category == "social"}>🤝 絆</option>
                    <option value="akasha" selected={@changeset.data.category == "akasha"}>φ 空環</option>
                    <option value="universal" selected={@changeset.data.category == "universal"}>🌈 万能</option>
                  </select>
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="talent_card[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-field">
                  <label>互換タグ（カンマ区切り）</label>
                  <input type="text" name="talent_card[compatible_tags]" value={Enum.join(@changeset.data.compatible_tags || [], ", ")} placeholder="対話, ケア, 森" />
                </div>
                <div class="card-form-row">
                  <div class="card-form-field">
                    <label>効果タイプ</label>
                    <select name="talent_card[effect_type]">
                      <option value="bonus" selected={@changeset.data.effect_type == "bonus"}>ボーナス</option>
                      <option value="cost_reduction" selected={@changeset.data.effect_type == "cost_reduction"}>コスト削減</option>
                      <option value="extra_effect" selected={@changeset.data.effect_type == "extra_effect"}>追加効果</option>
                    </select>
                  </div>
                  <div class="card-form-field small">
                    <label>効果値</label>
                    <input type="number" name="talent_card[effect_value]" value={@changeset.data.effect_value || 1} min="1" />
                  </div>
                </div>
                <div class="card-form-actions">
                  <button type="submit" class="btn-save">保存</button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">キャンセル</button>
                </div>
              </.form>
            <% else %>
              <div class="card-header">
                <span class="card-type-badge"><%= category_label(card.category) %></span>
                <h3><%= card.name %></h3>
                <button type="button" class="btn-edit-card" phx-click="start_edit" phx-value-card-id={card.id}>
                  編集
                </button>
              </div>
              <div class="card-body">
                <%= if card.description do %>
                  <p class="card-flavor"><%= card.description %></p>
                <% end %>
                <div class="card-tags">
                  <%= for tag <- (card.compatible_tags || []) do %>
                    <span class="tag"><%= tag %></span>
                  <% end %>
                </div>
              </div>
              <div class="card-footer">
                <p class="card-effect">
                  <%= case card.effect_type do %>
                    <% "bonus" -> %>ボーナス +<%= card.effect_value %>
                    <% "cost_reduction" -> %>コスト -<%= card.effect_value %>
                    <% "extra_effect" -> %>全効果 +<%= card.effect_value %>
                    <% _ -> %><%= card.effect_type %>: <%= card.effect_value %>
                  <% end %>
                </p>
              </div>
            <% end %>
          </article>
        <% end %>
      </section>

      <%!-- 新規カード作成フォーム --%>
      <%= if @show_new_form do %>
        <section class="new-card-form-section">
          <h3>新規才能カード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="talent_card[name]" required placeholder="カードの名前" />
            </div>
            <div class="card-form-field">
              <label>カテゴリ *</label>
              <select name="talent_card[category]" required>
                <option value="forest">🌲 森</option>
                <option value="culture">🎭 文化</option>
                <option value="social">🤝 絆</option>
                <option value="akasha">φ 空環</option>
                <option value="universal">🌈 万能</option>
              </select>
            </div>
            <div class="card-form-field">
              <label>説明 *</label>
              <textarea name="talent_card[description]" rows="2" required placeholder="カードの説明"></textarea>
            </div>
            <div class="card-form-field">
              <label>互換タグ（カンマ区切り）</label>
              <input type="text" name="talent_card[compatible_tags]" placeholder="対話, ケア, 森" />
            </div>
            <div class="card-form-row">
              <div class="card-form-field">
                <label>効果タイプ</label>
                <select name="talent_card[effect_type]">
                  <option value="bonus">ボーナス</option>
                  <option value="cost_reduction">コスト削減</option>
                  <option value="extra_effect">追加効果</option>
                </select>
              </div>
              <div class="card-form-field small">
                <label>効果値</label>
                <input type="number" name="talent_card[effect_value]" value="1" min="1" />
              </div>
            </div>
            <div class="card-form-actions">
              <button type="submit" class="btn-save">作成</button>
              <button type="button" class="btn-cancel" phx-click="cancel_new">キャンセル</button>
            </div>
          </.form>
        </section>
      <% end %>

      <footer class="catalog-footer">
        <p>神環記 カードカタログ</p>
        <a href="/" class="back-link">← トップに戻る</a>
      </footer>
    </main>
    """
  end
end
