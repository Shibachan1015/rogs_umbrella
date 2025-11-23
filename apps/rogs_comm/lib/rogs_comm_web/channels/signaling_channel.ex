defmodule RogsCommWeb.SignalingChannel do
  @moduledoc """
  Handles WebRTC signaling messages (offer/answer/ice) for a room.
  """

  use RogsCommWeb, :channel

  alias Ecto.UUID
  alias RogsComm.Rooms

  @rtc_events ~w(offer answer ice-candidate)
  @allowed_events @rtc_events ++ ~w(peer-ready)

  @impl true
  def join("signal:" <> room_id, _payload, socket) do
    with {:ok, uuid} <- UUID.cast(room_id),
         room when not is_nil(room) <- Rooms.fetch_room(uuid) do
      {:ok, %{room_id: room.id}, assign(socket, :room_id, room.id)}
    else
      _ -> {:error, %{reason: "room not found"}}
    end
  end

  @impl true
  def handle_in(event, payload, socket) when event in @rtc_events do
    case normalize_payload(event, payload, socket) do
      {:ok, normalized} ->
        broadcast(socket, event, normalized)
        {:noreply, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in(event, payload, socket) when event in @allowed_events do
    broadcast(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{reason: "unsupported signaling event"}}, socket}
  end

  defp normalize_payload(event, payload, socket) do
    room_id = socket.assigns.room_id
    from = socket.assigns[:user_id] || "anonymous"

    case validate_payload(event, payload) do
      :ok ->
        allowed_keys = ~w(room_id from to sdp candidate sdpMid sdpMLineIndex constraints)

        normalized =
          payload
          |> Map.take(allowed_keys)
          |> Map.put("room_id", room_id)
          |> Map.put_new("from", from)
          |> Map.put_new("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())

        {:ok, normalized}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_payload("offer", %{"sdp" => sdp}) when is_binary(sdp), do: :ok
  defp validate_payload("answer", %{"sdp" => sdp}) when is_binary(sdp), do: :ok
  defp validate_payload("ice-candidate", %{"candidate" => cand}) when is_binary(cand), do: :ok
  defp validate_payload(_event, _payload), do: {:error, "invalid payload"}
end
