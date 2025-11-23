defmodule RogsComm.MessagesFixtures do
  @moduledoc """
  Fixtures for the Messages context.
  """

  alias RogsComm.Messages
  alias RogsComm.RoomsFixtures

  def message_attrs(attrs \\ %{}) do
    room = Map.get(attrs, :room) || RoomsFixtures.room_fixture()

    attrs
    |> Map.drop([:room])
    |> Enum.into(%{
      content: "Hello world #{System.unique_integer([:positive])}",
      user_id: Ecto.UUID.generate(),
      user_email: "user#{System.unique_integer([:positive])}@example.com",
      room_id: room.id
    })
  end

  def message_fixture(attrs \\ %{}) do
    attrs
    |> message_attrs()
    |> Messages.create_message()
    |> case do
      {:ok, message} -> message
      {:error, changeset} -> raise "message_fixture failed: #{inspect(changeset.errors)}"
    end
  end
end
