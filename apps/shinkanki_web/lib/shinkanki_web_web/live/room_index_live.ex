defmodule ShinkankiWebWeb.RoomIndexLive do
  @moduledoc """
  LiveView for listing and creating game rooms.
  Integrated with rogs_comm room functionality.
  """

  use ShinkankiWebWeb, :live_view

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
      |> assign(:show_create_form, false)

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
      {:ok, room} ->
        rooms = load_rooms(socket.assigns.filters)
        changeset = Room.changeset(%Room{}, %{})

        {:noreply,
         socket
         |> put_flash(:info, "ルームを作成しました")
         |> assign(:rooms, rooms)
         |> assign(:form, to_form(changeset))
         |> assign(:show_create_form, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("filter", %{"filters" => filters_params}, socket) do
    filters = %{
      query: filters_params["query"] || "",
      show_private?: filters_params["show_private?"] == "true"
    }

    rooms = load_rooms(filters)

    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filter_form_data(filters)))}
  end

  @impl true
  def handle_event("toggle_create_form", _params, socket) do
    {:noreply, update(socket, :show_create_form, &(!&1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen resonance-shell bg-[var(--color-landing-bg)] text-[var(--color-landing-text-primary)]">
      <div class="container mx-auto px-4 py-8 max-w-6xl">
        <!-- Header -->
        <div class="mb-8 text-center">
          <h1 class="text-4xl md:text-5xl font-bold text-[var(--color-landing-pale)] mb-4 tracking-[0.2em]">
            神環記
          </h1>
          <p class="text-lg text-[var(--color-landing-text-secondary)] tracking-[0.1em]">
            ゲームルーム一覧
          </p>
        </div>

        <!-- Filter and Create Button -->
        <div class="mb-6 flex flex-col sm:flex-row gap-4 items-center justify-between">
          <.form
            for={@filter_form}
            phx-change="filter"
            class="flex-1 max-w-md w-full"
          >
            <.input
              field={@filter_form[:query]}
              type="text"
              placeholder="ルーム名で検索..."
              class="hud-chat-input"
            />
          </.form>

          <button
            type="button"
            class="cta-button cta-solid px-6 py-3 tracking-[0.3em]"
            phx-click="toggle_create_form"
          >
            {if @show_create_form, do: "キャンセル", else: "+ ルーム作成"}
          </button>
        </div>

        <!-- Create Room Form -->
        <%= if @show_create_form do %>
          <div class="mb-8 resonance-card p-6 border-2 border-shu/30">
            <h2 class="text-xl font-bold text-[var(--color-landing-pale)] mb-4 tracking-[0.2em]">
              新しいルームを作成
            </h2>
            <.form
              for={@form}
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <.input
                field={@form[:name]}
                type="text"
                label="ルーム名"
                placeholder="例: 第1回神環記"
                class="hud-chat-input"
                required
              />
              <.input
                field={@form[:slug]}
                type="text"
                label="スラッグ（URL用）"
                placeholder="例: game-001"
                class="hud-chat-input"
              />
              <.input
                field={@form[:topic]}
                type="textarea"
                label="説明"
                placeholder="ルームの説明を入力..."
                class="hud-chat-input min-h-20"
              />
              <.input
                field={@form[:max_participants]}
                type="number"
                label="最大参加人数"
                class="hud-chat-input"
                value={@form[:max_participants].value || 4}
                min="2"
                max="8"
              />
              <div class="flex gap-4">
                <button
                  type="submit"
                  class="cta-button cta-solid flex-1 justify-center tracking-[0.3em]"
                >
                  作成
                </button>
                <button
                  type="button"
                  class="cta-button cta-outline flex-1 justify-center tracking-[0.3em]"
                  phx-click="toggle_create_form"
                >
                  キャンセル
                </button>
              </div>
            </.form>
          </div>
        <% end %>

        <!-- Room List -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for room <- @rooms do %>
            <div class="resonance-card p-6 border-2 border-white/10 hover:border-shu/50 transition-all duration-300">
              <div class="flex items-start justify-between mb-3">
                <h3 class="text-xl font-bold text-[var(--color-landing-pale)] tracking-[0.1em]">
                  {room.name}
                </h3>
                <%= if room.is_private do %>
                  <span class="text-xs px-2 py-1 bg-shu/20 text-shu border border-shu/40 rounded tracking-[0.2em]">
                    非公開
                  </span>
                <% end %>
              </div>

              <%= if room.topic do %>
                <p class="text-sm text-[var(--color-landing-text-secondary)] mb-4 line-clamp-2">
                  {room.topic}
                </p>
              <% end %>

              <div class="flex items-center justify-between text-xs text-[var(--color-landing-text-secondary)] mb-4">
                <span>最大参加人数: {room.max_participants}</span>
                <time datetime={DateTime.to_iso8601(room.inserted_at)}>
                  {format_date(room.inserted_at)}
                </time>
              </div>

              <.link
                navigate={~p"/game/#{room.id}"}
                class="cta-button cta-solid w-full justify-center tracking-[0.3em]"
              >
                参加する
              </.link>
            </div>
          <% end %>
        </div>

        <%= if length(@rooms) == 0 do %>
          <div class="text-center py-12 text-[var(--color-landing-text-secondary)]">
            <p class="text-lg mb-2">ルームが見つかりません</p>
            <p class="text-sm">新しいルームを作成してください</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_rooms(filters) do
    opts = [
      include_private: filters.show_private?
    ]

    rooms = Rooms.list_rooms(opts)

    if filters.query != "" do
      query_lower = String.downcase(filters.query)
      Enum.filter(rooms, fn room ->
        String.contains?(String.downcase(room.name), query_lower) ||
          (room.topic && String.contains?(String.downcase(room.topic), query_lower))
      end)
    else
      rooms
    end
  end

  defp filter_form_data(filters) do
    %{
      "query" => filters.query,
      "show_private?" => filters.show_private?
    }
  end

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y/%m/%d")
  end

  defp format_date(_), do: ""
end
