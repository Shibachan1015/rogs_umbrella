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

  @impl true
  def mount(_params, _session, socket) do
    rooms = Rooms.list_rooms(include_private: false)

    changeset = Room.changeset(%Room{}, %{})

    socket =
      socket
      |> assign(:rooms, rooms)
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
        rooms = Rooms.list_rooms(include_private: false)
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
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">チャットルーム</h1>
          <p class="text-gray-600 mt-2">ルームを作成するか、既存のルームに参加してください</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div>
            <h2 class="text-xl font-semibold text-gray-900 mb-4">ルームを作成</h2>
            <.form for={@form} id="room-form" phx-change="validate" phx-submit="save" method="post">
              <.input
                field={@form[:name]}
                type="text"
                label="ルーム名"
                placeholder="例: 森の守り手の部屋"
                required
              />
              <.input
                field={@form[:topic]}
                type="text"
                label="トピック（任意）"
                placeholder="例: 森の管理について話し合います"
              />
              <.input
                field={@form[:is_private]}
                type="checkbox"
                label="非公開ルーム"
              />
              <button
                type="submit"
                class="mt-4 w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                作成
              </button>
            </.form>
          </div>

          <div>
            <h2 class="text-xl font-semibold text-gray-900 mb-4">ルーム一覧</h2>
            <div class="space-y-3">
              <div
                :for={room <- @rooms}
                class="border rounded-lg p-4 hover:bg-gray-50 transition"
              >
                <.link
                  navigate={~p"/rooms/#{room.id}/chat"}
                  class="block"
                >
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <h3 class="font-semibold text-gray-900">{room.name}</h3>
                      <p :if={room.topic} class="text-sm text-gray-600 mt-1">{room.topic}</p>
                      <div class="flex items-center gap-4 mt-2 text-xs text-gray-500">
                        <span>最大参加者: {room.max_participants}人</span>
                        <span :if={room.is_private} class="text-red-600">非公開</span>
                      </div>
                    </div>
                    <svg
                      class="w-5 h-5 text-gray-400"
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
              <div :if={@rooms == []} class="text-center text-gray-500 py-8">
                ルームがありません。新しいルームを作成してください。
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
