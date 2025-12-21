defmodule ShinkankiWebWeb.HitoyoCardsLive do
  @moduledoc """
  Hitoyo (Event) Cards catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.EventCard
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_event_cards()

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
    card = Cards.get_event_card(card_id)

    if card do
      changeset = Cards.change_event_card(card)

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
  def handle_event("save_edit", %{"event_card" => params}, socket) do
    card = Cards.get_event_card(socket.assigns.editing_card)

    case Cards.update_event_card(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_event_cards()

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
    changeset = Cards.change_event_card(%EventCard{})

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
  def handle_event("create_card", %{"event_card" => params}, socket) do
    case Cards.create_event_card(params) do
      {:ok, _card} ->
        cards = Cards.list_event_cards()

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

  defp type_label("positive"), do: "✨ ポジティブ"
  defp type_label("negative"), do: "💀 ネガティブ"
  defp type_label("choice"), do: "🔀 選択"
  defp type_label(_), do: "その他"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="card-catalog hitoyo-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>人代カード</h1>
        <p class="subtitle">Hitoyo Cards</p>
        <p class="description">
          現代社会の流れ（環境破壊・物理的誘惑・文化の切り捨て・分断など）を表すカード。
          引かれると、F/K/Sが減ったり、邪気が増えたりします。
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
        <a href="/cards/talent">才能</a>
        <a href="/cards/cocreation">共創</a>
        <a href="/cards/action">アクション</a>
        <a href="/cards/hitoyo" class="active">人代</a>
        <a href="/cards/migaki">磨き</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>人代カードとは</h2>
        <ul>
          <li>毎年の<strong>人代フェイズ</strong>で公開される「社会の圧力」</li>
          <li>邪気レベルに応じて引く枚数が変わる（邪気6〜8なら<strong>3枚</strong>）</li>
          <li><strong>ポジティブ</strong>：良い影響 / <strong>ネガティブ</strong>：悪い影響</li>
          <li><strong>選択</strong>：プレイヤーが選べる</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>人代カード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card hitoyo-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="event_card[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>タイプ</label>
                  <select name="event_card[type]">
                    <option value="positive" selected={@changeset.data.type == "positive"}>✨ ポジティブ</option>
                    <option value="negative" selected={@changeset.data.type == "negative"}>💀 ネガティブ</option>
                    <option value="choice" selected={@changeset.data.type == "choice"}>🔀 選択</option>
                  </select>
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="event_card[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>F効果</label>
                    <input type="number" name="event_card[effect_forest]" value={@changeset.data.effect_forest || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>K効果</label>
                    <input type="number" name="event_card[effect_culture]" value={@changeset.data.effect_culture || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>S効果</label>
                    <input type="number" name="event_card[effect_social]" value={@changeset.data.effect_social || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>φ効果</label>
                    <input type="number" name="event_card[effect_akasha]" value={@changeset.data.effect_akasha || 0} />
                  </div>
                </div>
                <div class="card-form-actions">
                  <button type="submit" class="btn-save">保存</button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">キャンセル</button>
                </div>
              </.form>
            <% else %>
              <div class="card-header">
                <span class="card-type-badge danger"><%= type_label(card.type) %></span>
                <h3><%= card.name %></h3>
                <button type="button" class="btn-edit-card" phx-click="start_edit" phx-value-card-id={card.id}>
                  編集
                </button>
              </div>
              <div class="card-body">
                <%= if card.description do %>
                  <p class="card-flavor"><%= card.description %></p>
                <% end %>
              </div>
              <div class="card-footer">
                <p class="card-effect negative">
                  効果: F:<%= if(card.effect_forest >= 0, do: "+", else: "") %><%= card.effect_forest %>
                  K:<%= if(card.effect_culture >= 0, do: "+", else: "") %><%= card.effect_culture %>
                  S:<%= if(card.effect_social >= 0, do: "+", else: "") %><%= card.effect_social %>
                  φ:<%= if(card.effect_akasha >= 0, do: "+", else: "") %><%= card.effect_akasha %>
                </p>
              </div>
            <% end %>
          </article>
        <% end %>
      </section>

      <%!-- 新規カード作成フォーム --%>
      <%= if @show_new_form do %>
        <section class="new-card-form-section">
          <h3>新規人代カード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="event_card[name]" required placeholder="カードの名前" />
            </div>
            <div class="card-form-field">
              <label>タイプ *</label>
              <select name="event_card[type]" required>
                <option value="positive">✨ ポジティブ</option>
                <option value="negative">💀 ネガティブ</option>
                <option value="choice">🔀 選択</option>
              </select>
            </div>
            <div class="card-form-field">
              <label>説明</label>
              <textarea name="event_card[description]" rows="2" placeholder="カードの説明"></textarea>
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>F効果</label>
                <input type="number" name="event_card[effect_forest]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>K効果</label>
                <input type="number" name="event_card[effect_culture]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>S効果</label>
                <input type="number" name="event_card[effect_social]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>φ効果</label>
                <input type="number" name="event_card[effect_akasha]" value="0" />
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
