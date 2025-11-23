defmodule RogsCommWeb.UserSocket do
  @moduledoc """
  Socket entry-point for chat connections.
  """

  use Phoenix.Socket

  channel "room:*", RogsCommWeb.ChatChannel
  channel "signal:*", RogsCommWeb.SignalingChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
