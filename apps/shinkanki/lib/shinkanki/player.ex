defmodule Shinkanki.Player do
  @moduledoc """
  Represents a player in the Shinkanki game.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          talents: list(atom()),
          used_talents: list(atom()),
          is_ready: boolean(),
          is_ai: boolean()
        }

  defstruct [:id, :name, :role, talents: [], used_talents: [], is_ready: false, is_ai: false]

  @doc """
  Creates a new player.
  """
  def new(id, name, role \\ nil) do
    %__MODULE__{id: id, name: name, role: role, is_ai: false}
  end
end
