defmodule RogsIdentity.Accounts.UserNotifier do
  import Swoosh.Email

  alias RogsIdentity.Mailer
  alias RogsIdentity.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Torii Identity · 神環記", "auth@torii.identity"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp trds_body(title, lines) when is_list(lines) do
    """
    ── #{title} ────────────────────────────────

    #{Enum.join(lines, "\n\n")}

    ────────────────────────────────────────────
    Torii Identity · 神環記
    """
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Torii Identity | Confirm your new address",
      trds_body("Update Email", [
        "Hi #{user.email},",
        "We received a request to move your account correspondence. Continue the passage by opening:\n\n#{url}",
        "If this resonance wasn't initiated by you, simply ignore this message and your address stays as-is."
      ])
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions_private(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_confirmation_instructions_private(user, url) do
    deliver(
      user.email,
      "Torii Identity | Confirm your arrival",
      trds_body("Account Confirmation", [
        "Hi #{user.email},",
        "Step through the Torii and activate your account:\n\n#{url}",
        "Didn't expect this? Disregard the mail and no changes will occur."
      ])
    )
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(
      user.email,
      "Torii Identity | One-tap login",
      trds_body("Magic Link", [
        "Hi #{user.email},",
        "Resume your session by visiting the link below within the next hour:\n\n#{url}",
        "If this wasn't you, you can safely ignore the message—no one gains access without the link."
      ])
    )
  end

  @doc """
  Deliver confirmation instructions (public function for resending).
  """
  def deliver_confirmation_instructions(user, url) do
    deliver_confirmation_instructions_private(user, url)
  end

  @doc """
  Deliver instructions to reset password.
  """
  def deliver_password_reset_instructions(user, url) do
    deliver(
      user.email,
      "Torii Identity | Password reset",
      trds_body("Reset Password", [
        "Hi #{user.email},",
        "Re-establish your credentials with the link below (valid for 6 hours):\n\n#{url}",
        "If this wasn't your action, you can ignore this notice—your password remains untouched."
      ])
    )
  end
end
