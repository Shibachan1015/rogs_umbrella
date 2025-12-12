defmodule ShinkankiWebWeb.AnnotationComponent do
  @moduledoc """
  Component for displaying and managing page annotations/comments.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders an annotation button that shows the comment count and opens the annotation panel.
  """
  attr :section_id, :string, required: true
  attr :count, :integer, default: 0
  attr :current_user, :any, default: nil

  def annotation_button(assigns) do
    ~H"""
    <button
      type="button"
      class="annotation-trigger"
      phx-click={JS.toggle(to: "#annotation-panel-#{@section_id}")}
      aria-label={"コメントを表示 (#{@count}件)"}
    >
      <span class="annotation-icon">💬</span>
      <%= if @count > 0 do %>
        <span class="annotation-count">{@count}</span>
      <% end %>
    </button>
    """
  end

  @doc """
  Renders the annotation panel with existing comments and a form for new comments.
  """
  attr :section_id, :string, required: true
  attr :page_path, :string, required: true
  attr :annotations, :list, default: []
  attr :current_user, :any, default: nil
  attr :changeset, :any, default: nil

  def annotation_panel(assigns) do
    ~H"""
    <div id={"annotation-panel-#{@section_id}"} class="annotation-panel" style="display: none;">
      <div class="annotation-panel-header">
        <h4>コメント</h4>
        <button
          type="button"
          class="annotation-close"
          phx-click={JS.hide(to: "#annotation-panel-#{@section_id}")}
        >
          ✕
        </button>
      </div>

      <div class="annotation-list">
        <%= if Enum.empty?(@annotations) do %>
          <p class="annotation-empty">まだコメントはありません</p>
        <% else %>
          <%= for annotation <- @annotations do %>
            <.annotation_item
              annotation={annotation}
              current_user={@current_user}
              section_id={@section_id}
            />
          <% end %>
        <% end %>
      </div>

      <%= if @current_user do %>
        <.annotation_form
          section_id={@section_id}
          page_path={@page_path}
          current_user={@current_user}
        />
      <% else %>
        <div class="annotation-login-prompt">
          <p>コメントするにはログインが必要です</p>
          <a href="http://localhost:4001/auth/google" class="oauth-btn oauth-google">
            Googleでログイン
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single annotation item.
  """
  attr :annotation, :map, required: true
  attr :current_user, :any, default: nil
  attr :section_id, :string, required: true

  def annotation_item(assigns) do
    ~H"""
    <div class="annotation-item" id={"annotation-#{@annotation.id}"}>
      <div class="annotation-meta">
        <span class="annotation-author">
          {get_author_name(@annotation)}
        </span>
        <span class="annotation-date">
          {format_date(@annotation.inserted_at)}
        </span>
        <%= if @current_user && @current_user.id == @annotation.user_id do %>
          <button
            type="button"
            class="annotation-delete"
            phx-click="delete_annotation"
            phx-value-id={@annotation.id}
            phx-value-section={@section_id}
          >
            削除
          </button>
        <% end %>
      </div>
      <div class="annotation-content">
        {@annotation.content}
      </div>
    </div>
    """
  end

  @doc """
  Renders the annotation form for adding new comments.
  """
  attr :section_id, :string, required: true
  attr :page_path, :string, required: true
  attr :current_user, :any, required: true

  def annotation_form(assigns) do
    ~H"""
    <form
      class="annotation-form"
      phx-submit="create_annotation"
      phx-value-section={@section_id}
      phx-value-path={@page_path}
    >
      <textarea
        name="content"
        placeholder="コメントを入力..."
        rows="3"
        required
        minlength="1"
        maxlength="2000"
      ></textarea>
      <button type="submit" class="annotation-submit">
        投稿
      </button>
    </form>
    """
  end

  defp get_author_name(%{user_id: user_id}) do
    case RogsIdentity.Accounts.get_user(user_id) do
      nil -> "匿名ユーザー"
      user -> RogsIdentity.Accounts.display_name(user)
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y/%m/%d %H:%M")
  end
end
