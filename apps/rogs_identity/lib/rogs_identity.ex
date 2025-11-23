defmodule RogsIdentity do
  @moduledoc """
  RogsIdentity keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias RogsIdentity.Accounts.User

  defdelegate get_user(id), to: RogsIdentity.Accounts

  @doc """
  Gets the display name for a user by ID.
  Returns the user's name if set, otherwise falls back to email.
  Returns "Anonymous" if user is not found.

  ## Examples

      iex> get_display_name(user_id)
      "John Doe"

      iex> get_display_name(nonexistent_id)
      "Anonymous"

  """
  def get_display_name(user_id) do
    case get_user(user_id) do
      nil -> "Anonymous"
      user -> User.display_name(user)
    end
  end
end
