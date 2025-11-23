defmodule RogsCommWeb.Presence do
  @moduledoc """
  Tracks user presence in chat rooms.
  """
  use Phoenix.Presence,
    otp_app: :rogs_comm,
    pubsub_server: RogsComm.PubSub
end
