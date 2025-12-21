defmodule ShinkankiWebWeb.RulebookLive do
  @moduledoc """
  ルールブック - Wiki的な編集機能付き
  誰でも編集可能、履歴管理とロールバック機能あり
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Rulebook
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # 初期データをシード（テーブルが空の場合）
    if connected?(socket) do
      Rulebook.seed_initial_content()
    end

    sections = Rulebook.list_sections()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:sections, sections)
      |> assign(:editing_section, nil)
      |> assign(:edit_title, "")
      |> assign(:edit_content, "")
      |> assign(:show_history, nil)
      |> assign(:history, [])
      |> assign(:user_cache, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("start_edit", %{"section-id" => section_id}, socket) do
    section = Rulebook.get_section(section_id)

    if section do
      {:noreply,
       socket
       |> assign(:editing_section, section_id)
       |> assign(:edit_title, section.title)
       |> assign(:edit_content, section.content)}
    else
      {:noreply, put_flash(socket, :error, "セクションが見つかりません")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_section, nil)
     |> assign(:edit_title, "")
     |> assign(:edit_content, "")}
  end

  @impl true
  def handle_event("update_title", %{"value" => value}, socket) do
    {:noreply, assign(socket, :edit_title, value)}
  end

  @impl true
  def handle_event("update_content", %{"value" => value}, socket) do
    {:noreply, assign(socket, :edit_content, value)}
  end

  @impl true
  def handle_event("save_edit", _params, socket) do
    section_id = socket.assigns.editing_section
    title = String.trim(socket.assigns.edit_title)
    content = String.trim(socket.assigns.edit_content)
    user = socket.assigns.current_user

    cond do
      title == "" ->
        {:noreply, put_flash(socket, :error, "タイトルを入力してください")}

      content == "" ->
        {:noreply, put_flash(socket, :error, "内容を入力してください")}

      true ->
        section = Rulebook.get_section(section_id)

        if section do
          user_id = if user, do: user.id, else: nil

          case Rulebook.update_section(section, %{
                 title: title,
                 content: content,
                 updated_by: user_id
               }) do
            {:ok, _updated} ->
              sections = Rulebook.list_sections()

              {:noreply,
               socket
               |> assign(:sections, sections)
               |> assign(:editing_section, nil)
               |> assign(:edit_title, "")
               |> assign(:edit_content, "")
               |> put_flash(:info, "保存しました（v#{section.version + 1}）")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "保存に失敗しました")}
          end
        else
          {:noreply, put_flash(socket, :error, "セクションが見つかりません")}
        end
    end
  end

  @impl true
  def handle_event("show_history", %{"section-id" => section_id}, socket) do
    history = Rulebook.get_section_history(section_id)

    {:noreply,
     socket
     |> assign(:show_history, section_id)
     |> assign(:history, history)}
  end

  @impl true
  def handle_event("hide_history", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_history, nil)
     |> assign(:history, [])}
  end

  @impl true
  def handle_event("rollback", %{"section-id" => section_id, "version" => version}, socket) do
    version = String.to_integer(version)
    user = socket.assigns.current_user
    user_id = if user, do: user.id, else: nil

    case Rulebook.rollback_section(section_id, version, user_id, "ロールバック") do
      {:ok, _section} ->
        sections = Rulebook.list_sections()

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:show_history, nil)
         |> assign(:history, [])
         |> put_flash(:info, "バージョン #{version} に戻しました")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "ロールバックに失敗しました")}
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp render_markdown(content) do
    content
    |> String.split("\n")
    |> Enum.map(fn line ->
      line
      |> String.replace(~r/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
      |> String.replace(~r/^- (.+)$/, "<li>\\1</li>")
      |> String.replace(~r/^(\d+)\. (.+)$/, "<li>\\2</li>")
    end)
    |> Enum.join("<br>")
    |> Phoenix.HTML.raw()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="rulebook">
      <header class="rulebook-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <p class="eyebrow">Shinkanki Rulebook</p>
        <h1>神環記　ルールブック v0.4</h1>
        <p class="subtitle">
          八岐大蛇が目覚めたあとの 20 年間を描く、協力型の物語ボードゲーム。<br />
          森（F）・文化（K）・絆（S）を育て、いのち指数 L=40 を目指します。
        </p>
        <div class="wiki-notice">
          <p>このページは誰でも編集できます。各セクションの「編集」ボタンから内容を改善してください。</p>
        </div>
      </header>

      <nav class="rulebook-toc">
        <h2>目次</h2>
        <ol>
          <%= for section <- @sections do %>
            <li><a href={"##{section.section_id}"}><%= section.title %></a></li>
          <% end %>
        </ol>
      </nav>

      <article class="rulebook-content">
        <%= for section <- @sections do %>
          <section id={section.section_id} class="rulebook-section">
            <%= if @editing_section == section.section_id do %>
              <%!-- 編集モード --%>
              <div class="edit-form">
                <div class="edit-field">
                  <label>タイトル</label>
                  <input
                    type="text"
                    value={@edit_title}
                    phx-keyup="update_title"
                    phx-debounce="100"
                    class="edit-title-input"
                  />
                </div>
                <div class="edit-field">
                  <label>内容（Markdown記法可：**太字**、- リスト）</label>
                  <textarea
                    phx-keyup="update_content"
                    phx-debounce="100"
                    rows="12"
                    class="edit-content-input"
                  ><%= @edit_content %></textarea>
                </div>
                <div class="edit-actions">
                  <button type="button" class="btn-save" phx-click="save_edit">
                    保存
                  </button>
                  <button type="button" class="btn-cancel" phx-click="cancel_edit">
                    キャンセル
                  </button>
                </div>
              </div>
            <% else %>
              <%!-- 閲覧モード --%>
              <div class="section-header">
                <h2><%= section.title %></h2>
                <div class="section-actions">
                  <button
                    type="button"
                    class="btn-edit"
                    phx-click="start_edit"
                    phx-value-section-id={section.section_id}
                  >
                    編集
                  </button>
                  <button
                    type="button"
                    class="btn-history"
                    phx-click="show_history"
                    phx-value-section-id={section.section_id}
                  >
                    履歴 (v<%= section.version %>)
                  </button>
                </div>
              </div>
              <div class="section-content">
                <%= render_markdown(section.content) %>
              </div>
            <% end %>

            <%!-- 履歴パネル --%>
            <%= if @show_history == section.section_id do %>
              <div class="history-panel">
                <div class="history-header">
                  <h3>編集履歴</h3>
                  <button type="button" class="btn-close" phx-click="hide_history">×</button>
                </div>
                <%= if Enum.empty?(@history) do %>
                  <p class="history-empty">まだ編集履歴がありません</p>
                <% else %>
                  <div class="history-list">
                    <%= for h <- @history do %>
                      <div class="history-item">
                        <div class="history-meta">
                          <span class="history-version">v<%= h.version %></span>
                          <span class="history-date"><%= format_datetime(h.inserted_at) %></span>
                          <span class="history-author">
                            <%= h.editor_name || "匿名" %>
                          </span>
                        </div>
                        <div class="history-title"><%= h.title %></div>
                        <div class="history-actions">
                          <button
                            type="button"
                            class="btn-rollback"
                            phx-click="rollback"
                            phx-value-section-id={section.section_id}
                            phx-value-version={h.version}
                            data-confirm={"バージョン #{h.version} に戻しますか？"}
                          >
                            このバージョンに戻す
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </section>
        <% end %>

        <%= if Enum.empty?(@sections) do %>
          <div class="rulebook-loading">
            <p>ルールブックを読み込み中...</p>
          </div>
        <% end %>
      </article>
    </main>
    """
  end
end
