defmodule RogsCommWeb.RoomIndexLive do
  @moduledoc """
  LiveView for listing and creating chat rooms.

  ⚠️ NOTE:
    This LiveView provides a developer-facing room management UI.
    The final player-facing UI is expected to live in the `rogs-ui`
    / `shinkanki_web` worktree and should replace this module when
    the design system implementation is ready.
  """

  use RogsCommWeb, :live_view

  alias RogsComm.Rooms
  alias RogsComm.Rooms.Room

  @filter_defaults %{query: "", show_private?: false}

  @impl true
  def mount(_params, _session, socket) do
    filters = @filter_defaults
    rooms = load_rooms(filters)
    changeset = Room.changeset(%Room{}, %{})

    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:filters, filters)
      |> assign(:filter_form, to_form(filter_form_data(filters)))
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset =
      %Room{}
      |> Room.changeset(room_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"room" => room_params}, socket) do
    case Rooms.create_room(room_params) do
      {:ok, _room} ->
        rooms = load_rooms(socket.assigns.filters)
        changeset = Room.changeset(%Room{}, %{})

        {:noreply,
         socket
         |> put_flash(:info, "ルームを作成しました")
         |> assign(:rooms, rooms)
         |> assign(:form, to_form(changeset))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("filter", %{"filters" => filters_params}, socket) do
    filters = normalize_filters(filters_params)
    rooms = load_rooms(filters)

    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filter_form_data(filters)))}
  end

  def handle_event("filter", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="landing-body">
        <div class="torii-lines"></div>
        <div class="max-w-6xl mx-auto px-4 py-8 md:py-12">
          <div class="mb-8 md:mb-12 text-center">
            <h1 class="text-3xl md:text-4xl font-bold pb-4 inline-block" style="font-family: var(--trds-font-serif); letter-spacing: 0.3em; color: var(--color-landing-text-primary); border-bottom: 2px solid var(--trds-outline-strong);">
              チャットルーム
            </h1>
            <p class="mt-4 text-lg" style="color: var(--color-landing-text-secondary);">ルームを作成するか、既存のルームに参加してください</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 md:gap-12">
            <div class="trds-glass-panel">
              <h2 class="text-xl font-semibold mb-6 pl-3" style="color: var(--color-landing-text-primary); border-left: 4px solid var(--trds-outline-strong);">
                ルームを作成
              </h2>
              <.form for={@form} id="room-form" phx-change="validate" phx-submit="save">
                <.input
                  field={@form[:name]}
                  type="text"
                  label="ルーム名"
                  placeholder="例: 森の守り手の部屋"
                  required
                  class="trds-focusable"
                  style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                />
                <.input
                  field={@form[:topic]}
                  type="text"
                  label="トピック（任意）"
                  placeholder="例: 森の管理について話し合います"
                  class="trds-focusable"
                  style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                />
                <div class="mt-4">
                  <.input
                    field={@form[:is_private]}
                    type="checkbox"
                    label="非公開ルーム"
                    class="trds-focusable"
                    style="accent-color: var(--color-landing-gold);"
                  />
                </div>
                <button
                  type="submit"
                  class="mt-6 w-full cta-button cta-solid trds-focusable"
                >
                  作成
                </button>
              </.form>
            </div>

            <div>
              <h2 class="text-xl font-semibold mb-6 pl-3" style="color: var(--color-landing-text-primary); border-left: 4px solid var(--trds-outline-strong);">
                ルーム一覧
              </h2>

              <div class="trds-glass-panel space-y-4 mb-6">
                <.form
                  id="filters-form"
                  for={@filter_form}
                  phx-change="filter"
                  phx-submit="filter"
                  class="space-y-4"
                >
                  <div>
                    <label class="text-xs uppercase tracking-[0.4em]" style="color: var(--color-landing-text-secondary);">
                      キーワード
                    </label>
                    <.input
                      field={@filter_form[:query]}
                      type="text"
                      placeholder="ルーム名やトピックで検索"
                      class="mt-2 trds-focusable"
                      style="background: var(--trds-surface-glass); border-color: var(--trds-outline-soft); color: var(--color-landing-text-primary);"
                    />
                  </div>

                  <label class="flex items-center gap-3 text-sm font-medium" style="color: var(--color-landing-text-primary);">
                    <input
                      type="checkbox"
                      name="filters[show_private]"
                      value="true"
                      checked={@filters.show_private?}
                      class="h-4 w-4 trds-focusable"
                      style="accent-color: var(--color-landing-gold); border-color: var(--trds-outline-soft);"
                    /> 非公開ルームを表示
                  </label>
                </.form>

                <div class="text-xs" style="color: var(--color-landing-text-secondary);">
                  表示件数: {length(@rooms)}件 / 検索: {if @filters.query == "",
                    do: "なし",
                    else: @filters.query}
                </div>
              </div>

              <div class="space-y-4">
                <div
                  :for={room <- @rooms}
                  class="concept-card trds-focusable"
                >
                  <.link navigate={~p"/rooms/#{room.id}/chat"} class="block">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h3 class="font-semibold text-lg pl-2" style="color: var(--color-landing-text-primary); border-left: 2px solid var(--trds-outline-strong);">
                          {room.name}
                        </h3>
                        <p :if={room.topic} class="text-sm mt-2" style="color: var(--color-landing-text-secondary);">
                          {room.topic}
                        </p>
                        <div class="flex items-center gap-4 mt-3 text-xs">
                          <span class="trds-pill">
                            最大参加者: {room.max_participants}人
                          </span>
                          <span
                            :if={room.is_private}
                            class="trds-pill trds-pill--gold"
                          >
                            非公開
                          </span>
                        </div>
                      </div>
                      <svg
                        class="w-6 h-6 flex-shrink-0 ml-4"
                        style="color: var(--color-landing-gold);"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 5l7 7-7 7"
                        />
                      </svg>
                    </div>
                  </.link>
                </div>

                <div :if={@rooms == []} class="text-center py-12 concept-card">
                  <div class="text-4xl mb-4">🏛️</div>
                  <p class="text-lg" style="color: var(--color-landing-text-primary);">該当するルームがありません</p>
                  <p class="text-sm mt-2" style="color: var(--color-landing-text-secondary);">検索条件を変更するか、新しいルームを作成してください</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_rooms(%{query: query, show_private?: show_private?}) do
    Rooms.list_rooms(include_private: show_private?)
    |> Enum.filter(&matches_query?(&1, query))
  end

  defp matches_query?(_room, ""), do: true

  defp matches_query?(room, query) do
    pattern = String.downcase(query)

    [room.name, room.topic]
    |> Enum.filter(& &1)
    |> Enum.map(&String.downcase/1)
    |> Enum.any?(&String.contains?(&1, pattern))
  end

  defp normalize_filters(params) do
    query = params |> Map.get("query", "") |> String.trim()

    show_private? =
      params
      |> Map.get("show_private", "false")
      |> case do
        value when value in ["true", "on", "1"] -> true
        _ -> false
      end

    %{query: query, show_private?: show_private?}
  end

  defp filter_form_data(filters) do
    %{
      "query" => filters.query,
      "show_private" => if(filters.show_private?, do: "true", else: "false")
    }
  end
end
