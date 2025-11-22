defmodule RogsComm.RoomsFixtures do
  @moduledoc """
  Fixtures for the Rooms context.
  """

  alias RogsComm.Rooms

  def unique_room_slug do
    "room-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  def room_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Room #{System.unique_integer([:positive])}",
      slug: unique_room_slug(),
      topic: "A room used for testing",
      is_private: false,
      max_participants: 8
    })
  end

  def room_fixture(attrs \\ %{}) do
    attrs
    |> room_attrs()
    |> Rooms.create_room()
    |> case do
      {:ok, room} -> room
      {:error, changeset} -> raise "room_fixture failed: #{inspect(changeset.errors)}"
    end
  end
end
