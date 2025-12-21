defmodule ShinkankiWebWeb.ActionCardsLive do
  @moduledoc """
  ActionCards catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.ActionCard
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_action_cards()

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
    card = Cards.get_action_card(card_id)

    if card do
      changeset = Cards.change_action_card(card)

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
  def handle_event("save_edit", %{"action_card" => params}, socket) do
    card = Cards.get_action_card(socket.assigns.editing_card)

    case Cards.update_action_card(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_action_cards()

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
    changeset = Cards.change_action_card(%ActionCard{})

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
  def handle_event("create_card", %{"action_card" => params}, socket) do
    case Cards.create_action_card(params) do
      {:ok, _card} ->
        cards = Cards.list_action_cards()

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

  defp category_label("forest"), do: "🌲 森"
  defp category_label("culture"), do: "🎭 文化"
  defp category_label("social"), do: "🤝 絆"
  defp category_label("akasha"), do: "φ 空環"
  defp category_label(_), do: "その他"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="card-catalog action-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>アクションカード</h1>
        <p class="subtitle">Action Cards（営みカード）</p>
        <p class="description">
          その年に世界で起こす行動のカード。
          ものづくり、祭り、仕組みづくり、対話などが書かれています。
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
        <a href="/cards/action" class="active">アクション</a>
        <a href="/cards/hitoyo">人代</a>
        <a href="/cards/migaki">磨き</a>
        <a href="/cards/okami">大神様</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>アクションカードとは</h2>
        <ul>
          <li>営みフェイズで山札から<strong>3枚程度</strong>引いて公開</li>
          <li>必要な<strong>空環（P）</strong>を支払って実行</li>
          <li>才能カードのタグが一致すれば<strong>+1ボーナス</strong></li>
          <li>F（森）、K（文化）、S（コミュニティ）を回復させる効果が中心</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>アクションカード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card action-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="action_card[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>カテゴリ</label>
                  <select name="action_card[category]">
                    <option value="forest" selected={@changeset.data.category == "forest"}>🌲 森</option>
                    <option value="culture" selected={@changeset.data.category == "culture"}>🎭 文化</option>
                    <option value="social" selected={@changeset.data.category == "social"}>🤝 絆</option>
                    <option value="akasha" selected={@changeset.data.category == "akasha"}>φ 空環</option>
                  </select>
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="action_card[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>F効果</label>
                    <input type="number" name="action_card[effect_forest]" value={@changeset.data.effect_forest || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>K効果</label>
                    <input type="number" name="action_card[effect_culture]" value={@changeset.data.effect_culture || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>S効果</label>
                    <input type="number" name="action_card[effect_social]" value={@changeset.data.effect_social || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>φ効果</label>
                    <input type="number" name="action_card[effect_akasha]" value={@changeset.data.effect_akasha || 0} />
                  </div>
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>Fコスト</label>
                    <input type="number" name="action_card[cost_forest]" value={@changeset.data.cost_forest || 0} min="0" />
                  </div>
                  <div class="card-form-field small">
                    <label>Kコスト</label>
                    <input type="number" name="action_card[cost_culture]" value={@changeset.data.cost_culture || 0} min="0" />
                  </div>
                  <div class="card-form-field small">
                    <label>Sコスト</label>
                    <input type="number" name="action_card[cost_social]" value={@changeset.data.cost_social || 0} min="0" />
                  </div>
                  <div class="card-form-field small">
                    <label>φコスト</label>
                    <input type="number" name="action_card[cost_akasha]" value={@changeset.data.cost_akasha || 0} min="0" />
                  </div>
                </div>
                <div class="card-form-field">
                  <label>特殊効果</label>
                  <input type="text" name="action_card[special_effect]" value={@changeset.data.special_effect} />
                </div>
                <div class="card-form-field">
                  <label>画像URL</label>
                  <input type="url" name="action_card[image_url]" value={@changeset.data.image_url} placeholder="https://example.com/image.jpg" />
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
                <%= if card.image_url do %>
                  <div class="card-image">
                    <img src={card.image_url} alt={card.name} />
                  </div>
                <% end %>
                <%= if card.description do %>
                  <p class="card-flavor"><%= card.description %></p>
                <% end %>
                <div class="card-cost">
                  <span class="cost">コスト: F:<%= card.cost_forest %> K:<%= card.cost_culture %> S:<%= card.cost_social %> φ:<%= card.cost_akasha %></span>
                </div>
              </div>
              <div class="card-footer">
                <p class="card-effect">
                  効果: F:<%= if(card.effect_forest >= 0, do: "+", else: "") %><%= card.effect_forest %>
                  K:<%= if(card.effect_culture >= 0, do: "+", else: "") %><%= card.effect_culture %>
                  S:<%= if(card.effect_social >= 0, do: "+", else: "") %><%= card.effect_social %>
                  φ:<%= if(card.effect_akasha >= 0, do: "+", else: "") %><%= card.effect_akasha %>
                </p>
                <%= if card.special_effect do %>
                  <p class="card-special"><%= card.special_effect %></p>
                <% end %>
              </div>
            <% end %>
          </article>
        <% end %>
      </section>

      <%!-- 新規カード作成フォーム --%>
      <%= if @show_new_form do %>
        <section class="new-card-form-section">
          <h3>新規アクションカード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="action_card[name]" required placeholder="カードの名前" />
            </div>
            <div class="card-form-field">
              <label>カテゴリ *</label>
              <select name="action_card[category]" required>
                <option value="forest">🌲 森</option>
                <option value="culture">🎭 文化</option>
                <option value="social">🤝 絆</option>
                <option value="akasha">φ 空環</option>
              </select>
            </div>
            <div class="card-form-field">
              <label>説明</label>
              <textarea name="action_card[description]" rows="2" placeholder="カードの説明（フレーバーテキスト）"></textarea>
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>F効果</label>
                <input type="number" name="action_card[effect_forest]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>K効果</label>
                <input type="number" name="action_card[effect_culture]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>S効果</label>
                <input type="number" name="action_card[effect_social]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>φ効果</label>
                <input type="number" name="action_card[effect_akasha]" value="0" />
              </div>
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>Fコスト</label>
                <input type="number" name="action_card[cost_forest]" value="0" min="0" />
              </div>
              <div class="card-form-field small">
                <label>Kコスト</label>
                <input type="number" name="action_card[cost_culture]" value="0" min="0" />
              </div>
              <div class="card-form-field small">
                <label>Sコスト</label>
                <input type="number" name="action_card[cost_social]" value="0" min="0" />
              </div>
              <div class="card-form-field small">
                <label>φコスト</label>
                <input type="number" name="action_card[cost_akasha]" value="0" min="0" />
              </div>
            </div>
            <div class="card-form-field">
              <label>特殊効果</label>
              <input type="text" name="action_card[special_effect]" placeholder="特殊効果があれば記入" />
            </div>
            <div class="card-form-field">
              <label>画像URL</label>
              <input type="url" name="action_card[image_url]" placeholder="https://example.com/image.jpg" />
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
