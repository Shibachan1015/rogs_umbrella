defmodule ShinkankiWebWeb.StoryLive do
  @moduledoc """
  物語篇 - Wiki的な編集機能付き
  誰でも編集可能、履歴管理とロールバック機能あり
  """
  use ShinkankiWebWeb, :live_view

  alias Shinkanki.Stories
  alias RogsIdentity.Accounts
  alias ShinkankiWebWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # 初期データをシード（テーブルが空の場合）
    if connected?(socket) do
      Stories.seed_initial_content()
    end

    sections = Stories.list_sections()

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
      |> assign(:show_new_form, false)
      |> assign(:new_title, "")
      |> assign(:new_content, "")

    {:ok, socket}
  end

  @impl true
  def handle_event("start_edit", %{"section-id" => section_id}, socket) do
    section = Stories.get_section(section_id)

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
        section = Stories.get_section(section_id)

        if section do
          user_id = if user, do: user.id, else: nil

          case Stories.update_section(section, %{
                 title: title,
                 content: content,
                 updated_by: user_id
               }) do
            {:ok, _updated} ->
              sections = Stories.list_sections()

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
    history = Stories.get_section_history(section_id)

    # ユーザー情報を付加
    {history_with_users, user_cache} =
      Enum.map_reduce(history, socket.assigns.user_cache, fn h, cache ->
        case h.updated_by do
          nil ->
            {Map.put(h, :user, nil), cache}

          user_id ->
            case Map.get(cache, user_id) do
              nil ->
                user = Accounts.get_user(user_id)
                {Map.put(h, :user, user), Map.put(cache, user_id, user)}

              user ->
                {Map.put(h, :user, user), cache}
            end
        end
      end)

    {:noreply,
     socket
     |> assign(:show_history, section_id)
     |> assign(:history, history_with_users)
     |> assign(:user_cache, user_cache)}
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

    case Stories.rollback_section(section_id, version, user_id) do
      {:ok, _section} ->
        sections = Stories.list_sections()

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

  @impl true
  def handle_event("start_new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_form, true)
     |> assign(:new_title, "")
     |> assign(:new_content, "")}
  end

  @impl true
  def handle_event("cancel_new", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_form, false)
     |> assign(:new_title, "")
     |> assign(:new_content, "")}
  end

  @impl true
  def handle_event("update_new_title", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_title, value)}
  end

  @impl true
  def handle_event("update_new_content", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_content, value)}
  end

  @impl true
  def handle_event("create_section", _params, socket) do
    title = String.trim(socket.assigns.new_title)
    content = String.trim(socket.assigns.new_content)
    user = socket.assigns.current_user

    cond do
      title == "" ->
        {:noreply, put_flash(socket, :error, "タイトルを入力してください")}

      content == "" ->
        {:noreply, put_flash(socket, :error, "内容を入力してください")}

      true ->
        sections = Stories.list_sections()
        max_order = sections |> Enum.map(& &1.order_index) |> Enum.max(fn -> -1 end)
        section_id = "section-#{System.unique_integer([:positive])}"
        user_id = if user, do: user.id, else: nil

        case Stories.create_section(%{
               section_id: section_id,
               title: title,
               content: content,
               order_index: max_order + 1,
               updated_by: user_id
             }) do
          {:ok, _section} ->
            sections = Stories.list_sections()

            {:noreply,
             socket
             |> assign(:sections, sections)
             |> assign(:show_new_form, false)
             |> assign(:new_title, "")
             |> assign(:new_content, "")
             |> put_flash(:info, "新しいセクションを作成しました")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "セクションの作成に失敗しました")}
        end
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

    <main class="story">
      <header class="story-header">
        <a href="/" class="back-link">← トップに戻る</a>
        <p class="eyebrow">Story of Shinkanki</p>
        <h1>物語篇</h1>
        <p class="lede">
          八岐大蛇はすでに目覚め、人を腑抜けにする霧を都市へ放っています。<br />
          神々は「人が人として神性を取り戻す」ことを急いでいます。
        </p>
        <div class="story-wiki-notice">
          <p>このページは誰でも編集できます。各セクションの「編集」ボタンから内容を改善してください。</p>
        </div>
        <div class="wiki-actions">
          <button type="button" class="btn-add-section" phx-click="start_new">
            ＋ 新規セクション追加
          </button>
        </div>
      </header>

      <article class="story-content">
        <%= for section <- @sections do %>
          <section id={section.section_id} class="story-section">
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
                            <%= if h.user, do: h.user.email |> String.split("@") |> List.first(), else: "匿名" %>
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
          <div class="story-loading">
            <p>物語を読み込み中...</p>
          </div>
        <% end %>

        <%!-- 新規セクション作成フォーム --%>
        <%= if @show_new_form do %>
          <section class="story-section new-section-form">
            <div class="edit-form">
              <h3>新規セクション作成</h3>
              <div class="edit-field">
                <label>タイトル</label>
                <input
                  type="text"
                  value={@new_title}
                  phx-keyup="update_new_title"
                  phx-debounce="100"
                  class="edit-title-input"
                  placeholder="セクションのタイトルを入力"
                />
              </div>
              <div class="edit-field">
                <label>内容（Markdown記法可：**太字**、- リスト）</label>
                <textarea
                  phx-keyup="update_new_content"
                  phx-debounce="100"
                  rows="12"
                  class="edit-content-input"
                  placeholder="セクションの内容を入力"
                ><%= @new_content %></textarea>
              </div>
              <div class="edit-actions">
                <button type="button" class="btn-save" phx-click="create_section">
                  作成
                </button>
                <button type="button" class="btn-cancel" phx-click="cancel_new">
                  キャンセル
                </button>
              </div>
            </div>
          </section>
        <% end %>
      </article>
    </main>
    """
  end
end
