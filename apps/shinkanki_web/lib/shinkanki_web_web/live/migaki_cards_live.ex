defmodule ShinkankiWebWeb.MigakiCardsLive do
  @moduledoc """
  Migaki Cards (磨きカード) catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.MigakiCard
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_migaki_cards()

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
    card = Cards.get_migaki_card(card_id)

    if card do
      changeset = Cards.change_migaki_card(card)

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
  def handle_event("save_edit", %{"migaki_card" => params}, socket) do
    card = Cards.get_migaki_card(socket.assigns.editing_card)
    params = process_tags(params)

    case Cards.update_migaki_card(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_migaki_cards()

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
    changeset = Cards.change_migaki_card(%MigakiCard{})

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
  def handle_event("create_card", %{"migaki_card" => params}, socket) do
    params = process_tags(params)

    case Cards.create_migaki_card(params) do
      {:ok, _card} ->
        cards = Cards.list_migaki_cards()

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

  defp process_tags(params) do
    case Map.get(params, "tags") do
      nil -> params
      tags when is_binary(tags) ->
        tag_list = tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        Map.put(params, "tags", tag_list)
      _ -> params
    end
  end

  defp category_label("kitchen"), do: "台所"
  defp category_label("forest"), do: "森"
  defp category_label("festival"), do: "祭り"
  defp category_label("care"), do: "ケア"
  defp category_label("special"), do: "大技"
  defp category_label(nil), do: "その他"
  defp category_label(_), do: "その他"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="card-catalog migaki-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>磨きカード</h1>
        <p class="subtitle">Migaki Cards</p>
        <p class="description">
          世界を「きれいにしていく」行動のカード。
          森・文化・コミュニティを回復させつつ、邪気を下げる効果を持ちます。
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
        <a href="/cards/migaki" class="active">磨き</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>磨きカードとは</h2>
        <ul>
          <li>日々の<strong>丁寧な暮らし</strong>を表すカード</li>
          <li>F/K/Sを回復させながら<strong>邪気を−1〜−2</strong>下げる</li>
          <li>一部の人代カードの効果を<strong>軽減・無効化</strong>できる</li>
          <li>才能カードのタグが一致すれば<strong>+1ボーナス</strong></li>
          <li>台所系、発酵系、森系など様々なカテゴリがある</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>磨きカード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card migaki-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="migaki_card[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>カテゴリ</label>
                  <select name="migaki_card[category]">
                    <option value="kitchen" selected={@changeset.data.category == "kitchen"}>台所</option>
                    <option value="forest" selected={@changeset.data.category == "forest"}>森</option>
                    <option value="festival" selected={@changeset.data.category == "festival"}>祭り</option>
                    <option value="care" selected={@changeset.data.category == "care"}>ケア</option>
                    <option value="special" selected={@changeset.data.category == "special"}>大技</option>
                  </select>
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="migaki_card[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-field">
                  <label>タグ（カンマ区切り）</label>
                  <input type="text" name="migaki_card[tags]" value={Enum.join(@changeset.data.tags || [], ", ")} placeholder="台所, 発酵, てしごと" />
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>必要P</label>
                    <input type="number" name="migaki_card[cost_akasha]" value={@changeset.data.cost_akasha || 0} min="0" />
                  </div>
                  <div class="card-form-field small">
                    <label>F効果</label>
                    <input type="number" name="migaki_card[effect_forest]" value={@changeset.data.effect_forest || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>K効果</label>
                    <input type="number" name="migaki_card[effect_culture]" value={@changeset.data.effect_culture || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>S効果</label>
                    <input type="number" name="migaki_card[effect_social]" value={@changeset.data.effect_social || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>邪気効果</label>
                    <input type="number" name="migaki_card[effect_jaki]" value={@changeset.data.effect_jaki || 0} />
                  </div>
                </div>
                <div class="card-form-field">
                  <label>特殊効果</label>
                  <input type="text" name="migaki_card[special_effect]" value={@changeset.data.special_effect} placeholder="特殊効果があれば" />
                </div>
                <div class="card-form-actions">
                  <button type="submit" class="btn-save">保存</button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">キャンセル</button>
                </div>
              </.form>
            <% else %>
              <div class="card-header">
                <span class="card-type-badge purify">磨き</span>
                <span class="card-category"><%= category_label(card.category) %></span>
                <h3><%= card.name %></h3>
                <button type="button" class="btn-edit-card" phx-click="start_edit" phx-value-card-id={card.id}>
                  編集
                </button>
              </div>
              <div class="card-body">
                <%= if card.description do %>
                  <p class="card-flavor"><%= card.description %></p>
                <% end %>
                <div class="card-cost">
                  <span class="cost">必要P: <%= card.cost_akasha || 0 %></span>
                </div>
                <div class="card-tags">
                  <%= for tag <- (card.tags || []) do %>
                    <span class="tag"><%= tag %></span>
                  <% end %>
                </div>
              </div>
              <div class="card-footer">
                <p class="card-effect positive">
                  <%= if card.effect_forest && card.effect_forest != 0 do %>F<%= if(card.effect_forest > 0, do: "+", else: "") %><%= card.effect_forest %> <% end %>
                  <%= if card.effect_culture && card.effect_culture != 0 do %>K<%= if(card.effect_culture > 0, do: "+", else: "") %><%= card.effect_culture %> <% end %>
                  <%= if card.effect_social && card.effect_social != 0 do %>S<%= if(card.effect_social > 0, do: "+", else: "") %><%= card.effect_social %> <% end %>
                  <%= if card.effect_jaki && card.effect_jaki != 0 do %>邪気<%= if(card.effect_jaki > 0, do: "+", else: "") %><%= card.effect_jaki %><% end %>
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
          <h3>新規磨きカード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="migaki_card[name]" required placeholder="カードの名前" />
            </div>
            <div class="card-form-field">
              <label>カテゴリ *</label>
              <select name="migaki_card[category]" required>
                <option value="kitchen">台所</option>
                <option value="forest">森</option>
                <option value="festival">祭り</option>
                <option value="care">ケア</option>
                <option value="special">大技</option>
              </select>
            </div>
            <div class="card-form-field">
              <label>説明</label>
              <textarea name="migaki_card[description]" rows="2" placeholder="カードの説明"></textarea>
            </div>
            <div class="card-form-field">
              <label>タグ（カンマ区切り）</label>
              <input type="text" name="migaki_card[tags]" placeholder="台所, 発酵, てしごと" />
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>必要P</label>
                <input type="number" name="migaki_card[cost_akasha]" value="1" min="0" />
              </div>
              <div class="card-form-field small">
                <label>F効果</label>
                <input type="number" name="migaki_card[effect_forest]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>K効果</label>
                <input type="number" name="migaki_card[effect_culture]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>S効果</label>
                <input type="number" name="migaki_card[effect_social]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>邪気効果</label>
                <input type="number" name="migaki_card[effect_jaki]" value="-1" />
              </div>
            </div>
            <div class="card-form-field">
              <label>特殊効果</label>
              <input type="text" name="migaki_card[special_effect]" placeholder="特殊効果があれば" />
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
