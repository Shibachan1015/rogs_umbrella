defmodule RogsIdentity do
  @moduledoc """
  RogsIdentity keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.

  ## Usage in Other Apps

  This module provides functions that can be called from other apps
  in the umbrella project (rogs_comm, shinkanki_web, etc.).

  ### Getting User Information

      # Get user by ID
      user = RogsIdentity.get_user(user_id)

      # Get display name
      name = RogsIdentity.get_display_name(user_id)

  ### Authentication Plugs

  Use `RogsIdentity.Plug` in your router:

      import RogsIdentity.Plug

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_current_user
      end

      pipeline :require_authenticated do
        plug :require_authenticated
      end

  ### Session Sharing

  Sessions are shared via cookies. Make sure all apps run on the same domain
  or configure cookie domain appropriately in production.
  """

  alias RogsIdentity.Accounts
  alias RogsIdentity.Accounts.User

  defdelegate get_user(id), to: Accounts
  defdelegate get_user!(id), to: Accounts
  defdelegate get_user_by_email(email), to: Accounts
  defdelegate get_user_by_session_token(token), to: Accounts

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

  @doc """
  Checks if a user is authenticated based on the session token.
  Returns the user if authenticated, nil otherwise.

  ## Examples

      iex> get_authenticated_user(session_token)
      %User{}

      iex> get_authenticated_user(invalid_token)
      nil

  """
  def get_authenticated_user(token) when is_binary(token) do
    case Accounts.get_user_by_session_token(token) do
      {user, _token_inserted_at} -> user
      nil -> nil
    end
  end

  def get_authenticated_user(_), do: nil
end
