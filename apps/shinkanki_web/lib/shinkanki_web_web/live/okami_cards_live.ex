defmodule ShinkankiWebWeb.OkamiCardsLive do
  @moduledoc """
  Okami Cards (大神様カード) catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.OkamiCard
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_okami_cards()

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
    card = Cards.get_okami_card(card_id)

    if card do
      changeset = Cards.change_okami_card(card)

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
  def handle_event("save_edit", %{"okami_card" => params}, socket) do
    card = Cards.get_okami_card(socket.assigns.editing_card)

    case Cards.update_okami_card(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_okami_cards()

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
    changeset = Cards.change_okami_card(%OkamiCard{})

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
  def handle_event("create_card", %{"okami_card" => params}, socket) do
    case Cards.create_okami_card(params) do
      {:ok, _card} ->
        cards = Cards.list_okami_cards()

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="card-catalog okami-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>大神様カード</h1>
        <p class="subtitle">Okami Cards</p>
        <p class="description">
          神々の祝福を表すカード。神様からの恵みにより、大地と人々に幸福をもたらします。
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
        <a href="/cards/hitoyo">人代</a>
        <a href="/cards/migaki">磨き</a>
        <a href="/cards/okami" class="active">大神様</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>大神様カードとは</h2>
        <ul>
          <li>神々の<strong>祝福</strong>を表すカード</li>
          <li>森・文化・絆に<strong>ポジティブな効果</strong>をもたらす</li>
          <li>特別なイベントとして発動される</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>大神様カード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card okami-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="okami_card[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>神様の名前</label>
                  <input type="text" name="okami_card[deity_name]" value={@changeset.data.deity_name} placeholder="天照大御神" />
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="okami_card[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-field">
                  <label>画像URL</label>
                  <input type="url" name="okami_card[image_url]" value={@changeset.data.image_url} placeholder="https://example.com/image.jpg" />
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>F効果</label>
                    <input type="number" name="okami_card[effect_forest]" value={@changeset.data.effect_forest || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>K効果</label>
                    <input type="number" name="okami_card[effect_culture]" value={@changeset.data.effect_culture || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>S効果</label>
                    <input type="number" name="okami_card[effect_social]" value={@changeset.data.effect_social || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>φ効果</label>
                    <input type="number" name="okami_card[effect_akasha]" value={@changeset.data.effect_akasha || 0} />
                  </div>
                </div>
                <div class="card-form-field">
                  <label>特殊効果</label>
                  <input type="text" name="okami_card[special_effect]" value={@changeset.data.special_effect} placeholder="特殊効果があれば" />
                </div>
                <div class="card-form-actions">
                  <button type="submit" class="btn-save">保存</button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">キャンセル</button>
                </div>
              </.form>
            <% else %>
              <div class="card-header">
                <span class="card-type-badge divine">大神様</span>
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
                <%= if card.deity_name do %>
                  <p class="card-deity"><%= card.deity_name %></p>
                <% end %>
                <%= if card.description do %>
                  <p class="card-flavor"><%= card.description %></p>
                <% end %>
              </div>
              <div class="card-footer">
                <p class="card-effect positive">
                  <%= if card.effect_forest && card.effect_forest != 0 do %>F<%= if(card.effect_forest > 0, do: "+", else: "") %><%= card.effect_forest %> <% end %>
                  <%= if card.effect_culture && card.effect_culture != 0 do %>K<%= if(card.effect_culture > 0, do: "+", else: "") %><%= card.effect_culture %> <% end %>
                  <%= if card.effect_social && card.effect_social != 0 do %>S<%= if(card.effect_social > 0, do: "+", else: "") %><%= card.effect_social %> <% end %>
                  <%= if card.effect_akasha && card.effect_akasha != 0 do %>φ<%= if(card.effect_akasha > 0, do: "+", else: "") %><%= card.effect_akasha %><% end %>
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
          <h3>新規大神様カード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="okami_card[name]" required placeholder="〇〇の祝福" />
            </div>
            <div class="card-form-field">
              <label>神様の名前</label>
              <input type="text" name="okami_card[deity_name]" placeholder="天照大御神" />
            </div>
            <div class="card-form-field">
              <label>説明</label>
              <textarea name="okami_card[description]" rows="2" placeholder="カードの説明"></textarea>
            </div>
            <div class="card-form-field">
              <label>画像URL</label>
              <input type="url" name="okami_card[image_url]" placeholder="https://example.com/image.jpg" />
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>F効果</label>
                <input type="number" name="okami_card[effect_forest]" value="1" />
              </div>
              <div class="card-form-field small">
                <label>K効果</label>
                <input type="number" name="okami_card[effect_culture]" value="1" />
              </div>
              <div class="card-form-field small">
                <label>S効果</label>
                <input type="number" name="okami_card[effect_social]" value="1" />
              </div>
              <div class="card-form-field small">
                <label>φ効果</label>
                <input type="number" name="okami_card[effect_akasha]" value="0" />
              </div>
            </div>
            <div class="card-form-field">
              <label>特殊効果</label>
              <input type="text" name="okami_card[special_effect]" placeholder="特殊効果があれば" />
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
