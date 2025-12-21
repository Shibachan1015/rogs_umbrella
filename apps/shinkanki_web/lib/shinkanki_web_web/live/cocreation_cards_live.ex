defmodule ShinkankiWebWeb.CocreationCardsLive do
  @moduledoc """
  Co-creation Cards (共創カード) catalog with wiki-style editing.
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Cards
  alias Shinkanki.Games.ProjectTemplate
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    cards = Cards.list_project_templates()

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
    card = Cards.get_project_template(card_id)

    if card do
      changeset = Cards.change_project_template(card)

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
  def handle_event("save_edit", %{"project_template" => params}, socket) do
    card = Cards.get_project_template(socket.assigns.editing_card)

    case Cards.update_project_template(card, params) do
      {:ok, _updated} ->
        cards = Cards.list_project_templates()

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
    changeset = Cards.change_project_template(%ProjectTemplate{})

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
  def handle_event("create_card", %{"project_template" => params}, socket) do
    case Cards.create_project_template(params) do
      {:ok, _card} ->
        cards = Cards.list_project_templates()

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

    <main class="card-catalog cocreation-catalog">
      <header class="catalog-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <h1>共創カード</h1>
        <p class="subtitle">Co-creation Cards</p>
        <p class="description">
          複数のプレイヤーが協力して達成する大きなプロジェクト。
          完了すると強力な効果を発揮しますが、空環（P）と時間を要します。
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
        <a href="/cards/cocreation" class="active">共創</a>
        <a href="/cards/action">アクション</a>
        <a href="/cards/hitoyo">人代</a>
        <a href="/cards/migaki">磨き</a>
        <a href="/cards/okami">大神様</a>
        <a href="/kuukan">空環</a>
      </nav>

      <section class="catalog-intro">
        <h2>共創カードとは</h2>
        <ul>
          <li>複数プレイヤーの協力が必要な<strong>大規模プロジェクト</strong></li>
          <li>達成には<strong>複数ターン</strong>にわたって空環（P）を蓄積する必要があります</li>
          <li>完了時に<strong>F/K/S を大幅に回復</strong>し、<strong>邪気を大きく下げる</strong>効果</li>
          <li>才能カードのボーナスは、毎ターンの貢献に適用されます</li>
        </ul>
      </section>

      <section class="card-grid">
        <h2>共創カード一覧 (<%= length(@cards) %>枚)</h2>

        <%= if Enum.empty?(@cards) do %>
          <p class="no-cards">カードがまだありません。「新規カード追加」から作成してください。</p>
        <% end %>

        <%= for card <- @cards do %>
          <article class="game-card cocreation-card">
            <%= if @editing_card == card.id do %>
              <.form for={@changeset} phx-submit="save_edit" class="card-edit-form">
                <div class="card-form-field">
                  <label>カード名</label>
                  <input type="text" name="project_template[name]" value={@changeset.data.name} required />
                </div>
                <div class="card-form-field">
                  <label>説明</label>
                  <textarea name="project_template[description]" rows="2"><%= @changeset.data.description %></textarea>
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>必要P</label>
                    <input type="number" name="project_template[required_dao_pool]" value={@changeset.data.required_dao_pool || 0} min="0" />
                  </div>
                  <div class="card-form-field small">
                    <label>必要人数</label>
                    <input type="number" name="project_template[required_participants]" value={@changeset.data.required_participants || 1} min="1" />
                  </div>
                  <div class="card-form-field small">
                    <label>必要年数</label>
                    <input type="number" name="project_template[required_turns]" value={@changeset.data.required_turns || 1} min="1" />
                  </div>
                </div>
                <div class="card-form-row">
                  <div class="card-form-field small">
                    <label>F効果</label>
                    <input type="number" name="project_template[effect_forest]" value={@changeset.data.effect_forest || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>K効果</label>
                    <input type="number" name="project_template[effect_culture]" value={@changeset.data.effect_culture || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>S効果</label>
                    <input type="number" name="project_template[effect_social]" value={@changeset.data.effect_social || 0} />
                  </div>
                  <div class="card-form-field small">
                    <label>φ効果</label>
                    <input type="number" name="project_template[effect_akasha]" value={@changeset.data.effect_akasha || 0} />
                  </div>
                </div>
                <div class="card-form-field">
                  <label>画像URL</label>
                  <input type="url" name="project_template[image_url]" value={@changeset.data.image_url} placeholder="https://example.com/image.jpg" />
                </div>
                <div class="card-form-actions">
                  <button type="submit" class="btn-save">保存</button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">キャンセル</button>
                </div>
              </.form>
            <% else %>
              <div class="card-header">
                <span class="card-type-badge">共創</span>
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
                <div class="card-requirements">
                  <span class="requirement">必要P: <%= card.required_dao_pool || 0 %></span>
                  <span class="requirement">期間: <%= card.required_turns || 1 %>年以上</span>
                  <span class="requirement">人数: <%= card.required_participants || 1 %>人</span>
                </div>
              </div>
              <div class="card-footer">
                <p class="card-effect">
                  完了時: F:<%= if(card.effect_forest >= 0, do: "+", else: "") %><%= card.effect_forest %>
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
          <h3>新規共創カード作成</h3>
          <.form for={@changeset} phx-submit="create_card" class="card-edit-form">
            <div class="card-form-field">
              <label>カード名 *</label>
              <input type="text" name="project_template[name]" required placeholder="カードの名前" />
            </div>
            <div class="card-form-field">
              <label>説明</label>
              <textarea name="project_template[description]" rows="2" placeholder="カードの説明"></textarea>
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>必要P</label>
                <input type="number" name="project_template[required_dao_pool]" value="10" min="0" />
              </div>
              <div class="card-form-field small">
                <label>必要人数</label>
                <input type="number" name="project_template[required_participants]" value="4" min="1" />
              </div>
              <div class="card-form-field small">
                <label>必要年数</label>
                <input type="number" name="project_template[required_turns]" value="2" min="1" />
              </div>
            </div>
            <div class="card-form-row">
              <div class="card-form-field small">
                <label>F効果</label>
                <input type="number" name="project_template[effect_forest]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>K効果</label>
                <input type="number" name="project_template[effect_culture]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>S効果</label>
                <input type="number" name="project_template[effect_social]" value="0" />
              </div>
              <div class="card-form-field small">
                <label>φ効果</label>
                <input type="number" name="project_template[effect_akasha]" value="0" />
              </div>
            </div>
            <div class="card-form-field">
              <label>画像URL</label>
              <input type="url" name="project_template[image_url]" placeholder="https://example.com/image.jpg" />
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
