defmodule RogsCommWeb.RoomController do
  use RogsCommWeb, :controller

  alias RogsComm.Rooms

  def create(conn, %{"room" => room_params}) do
    case Rooms.create_room(room_params) do
      {:ok, room} ->
        conn
        |> put_flash(:info, "ルームを作成しました")
        |> redirect(to: ~p"/rooms")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "ルームの作成に失敗しました")
        |> redirect(to: ~p"/rooms")
    end
  end
end
