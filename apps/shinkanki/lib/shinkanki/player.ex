defmodule Shinkanki.Player do
  @moduledoc """
  Represents a player in the Shinkanki game.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          avatar: String.t(),
          talents: list(atom()),
          used_talents: list(atom()),
          is_ready: boolean(),
          is_ai: boolean(),
          kuukan: integer(),
          musuhi_received: integer(),
          musuhi_available: integer()
        }

  defstruct [
    :id,
    :name,
    :role,
    avatar: "🎮",
    talents: [],
    used_talents: [],
    is_ready: false,
    is_ai: false,
    # 空環 (Kuukan) - Player's currency, initial value 3
    kuukan: 3,
    # むすひ received this turn
    musuhi_received: 0,
    # むすひ available to give (1 per turn)
    musuhi_available: 0
  ]

  @doc """
  Creates a new player with optional avatar.
  """
  def new(id, name, avatar \\ "🎮") do
    %__MODULE__{id: id, name: name, avatar: avatar, is_ai: false, kuukan: 3}
  end

  @doc """
  Checks if player can afford to pay the given kuukan cost.
  """
  def can_pay?(%__MODULE__{kuukan: kuukan}, cost) when cost <= kuukan, do: true
  def can_pay?(_player, _cost), do: false

  @doc """
  Pays kuukan cost from player's pool.
  """
  def pay_kuukan(%__MODULE__{kuukan: kuukan} = player, cost) when cost <= kuukan do
    {:ok, %{player | kuukan: kuukan - cost}}
  end

  def pay_kuukan(_player, _cost), do: {:error, :insufficient_kuukan}

  @doc """
  Adds kuukan to player's pool (from kanryu/還流).
  """
  def add_kuukan(%__MODULE__{} = player, amount) do
    %{player | kuukan: player.kuukan + amount}
  end

  @doc """
  Performs kanryu (還流) - spend kuukan to boost F/K/S.
  Returns {:ok, amount_spent} or {:error, reason}.
  Player must spend at least 1 if kuukan >= 5.
  """
  def must_kanryu?(%__MODULE__{kuukan: kuukan}) when kuukan >= 5, do: true
  def must_kanryu?(_player), do: false

  @doc """
  Gives musuhi chip to another player.
  """
  def give_musuhi(%__MODULE__{musuhi_available: 0} = _from_player, _to_player) do
    {:error, :no_musuhi_to_give}
  end

  def give_musuhi(%__MODULE__{musuhi_available: available} = from_player, to_player) do
    updated_from = %{from_player | musuhi_available: available - 1}
    updated_to = %{to_player | musuhi_received: to_player.musuhi_received + 1}
    {:ok, updated_from, updated_to}
  end

  @doc """
  Resets musuhi for new turn.
  """
  def reset_musuhi(%__MODULE__{} = player) do
    %{player | musuhi_available: 1, musuhi_received: 0}
  end

  @doc """
  Checks if player can acquire talent card (needs 2+ musuhi).
  """
  def can_acquire_talent?(%__MODULE__{musuhi_received: received}) when received >= 2, do: true
  def can_acquire_talent?(_player), do: false
end
