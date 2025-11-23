defmodule Shinkanki.Player do
  @moduledoc """
  Represents a player in the Shinkanki game.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          talents: list(atom()),
          used_talents: list(atom()),
          is_ready: boolean()
        }

  defstruct [:id, :name, talents: [], used_talents: [], is_ready: false]

  @doc """
  Creates a new player.
  """
  def new(id, name) do
    %__MODULE__{id: id, name: name}
  end
end
