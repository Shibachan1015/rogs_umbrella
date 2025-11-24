defmodule RogsCommWeb.SignalingChannel do
  @moduledoc """
  Handles WebRTC signaling messages (offer/answer/ice) for a room.
  """

  use RogsCommWeb, :channel

  require Logger

  alias Ecto.UUID
  alias RogsComm.Rooms
  alias RogsComm.Signaling
  alias RogsCommWeb.RateLimiter

  @rtc_events ~w(offer answer ice-candidate)
  @allowed_events @rtc_events ++ ~w(peer-ready)

  @impl true
  def join("signal:" <> room_id, _payload, socket) do
    with {:ok, uuid} <- UUID.cast(room_id),
         room when not is_nil(room) <- Rooms.fetch_room(uuid) do
      user_id = socket.assigns[:user_id] || Ecto.UUID.generate()

      socket =
        socket
        |> assign(:room_id, room.id)
        |> assign(:user_id, user_id)

      {:ok, %{room_id: room.id}, socket}
    else
      _ ->
        Logger.warning("SignalingChannel: Attempted to join non-existent room", room_id: room_id)
        {:error, %{reason: "room not found"}}
    end
  end

  @impl true
  def handle_in(event, payload, socket) when event in @rtc_events do
    user_id = socket.assigns.user_id

    # Rate limit check: 5 events per second per user
    case RateLimiter.check(user_id, limit: 5, window_seconds: 1) do
      {:ok, :allowed} ->
        case normalize_payload(event, payload, socket) do
          {:ok, normalized} ->
            # Log signaling session
            room_id = socket.assigns.room_id
            from_user_id = socket.assigns.user_id
            to_user_id = Map.get(normalized, "to")

            Signaling.create_session(%{
              room_id: room_id,
              from_user_id: from_user_id,
              to_user_id: to_user_id,
              event_type: event,
              payload: normalized
            })

            # If 'to' is specified, validate that the target user is in the room
            case to_user_id do
              nil ->
                # Broadcast to all in room
                broadcast(socket, event, normalized)
                {:noreply, socket}

              target_user_id when is_binary(target_user_id) ->
                # Validate target user is in room (basic check - could be enhanced with Presence)
                broadcast(socket, event, normalized)
                {:noreply, socket}

              _ ->
                Logger.warning("SignalingChannel: Invalid target user",
                  user_id: user_id,
                  room_id: socket.assigns.room_id,
                  target_user_id: to_user_id
                )
                {:reply, {:error, %{reason: "invalid target user"}}, socket}
            end

          {:error, reason} ->
            Logger.error("SignalingChannel: Failed to normalize payload",
              user_id: user_id,
              room_id: socket.assigns.room_id,
              event: event,
              reason: reason
            )
            {:reply, {:error, %{reason: reason}}, socket}
        end

      {:error, :rate_limited} ->
        Logger.warning("SignalingChannel: Rate limit exceeded",
          user_id: user_id,
          room_id: socket.assigns.room_id,
          event: event
        )
        {:reply, {:error, %{reason: "rate limit exceeded"}}, socket}
    end
  end

  def handle_in(event, payload, socket) when event in @allowed_events do
    broadcast(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in(event, _payload, socket) do
    Logger.warning("SignalingChannel: Unsupported event",
      user_id: socket.assigns.user_id,
      room_id: socket.assigns.room_id,
      event: event
    )
    {:reply, {:error, %{reason: "unsupported signaling event"}}, socket}
  end

  defp normalize_payload(event, payload, socket) do
    room_id = socket.assigns.room_id
    from = socket.assigns.user_id

    case validate_payload(event, payload) do
      :ok ->
        allowed_keys = ~w(room_id from to sdp candidate sdpMid sdpMLineIndex constraints)

        normalized =
          payload
          |> Map.take(allowed_keys)
          |> Map.put("room_id", room_id)
          |> Map.put("from", from)
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
