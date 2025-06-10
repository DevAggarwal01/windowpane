defmodule Windowpane.Creators.CreatorNotifier do
  import Swoosh.Email

  alias Windowpane.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Windowpane Studio", "studio@windowpane.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(creator, url) do
    deliver(creator.email, "Confirmation instructions", """

    ==============================

    Hi #{creator.name},

    You can confirm your creator account by visiting the URL below:

    #{url}

    If you didn't create a creator account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a creator password.
  """
  def deliver_reset_password_instructions(creator, url) do
    deliver(creator.email, "Reset password instructions", """

    ==============================

    Hi #{creator.name},

    You can reset your creator account password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a creator email.
  """
  def deliver_update_email_instructions(creator, url) do
    deliver(creator.email, "Update email instructions", """

    ==============================

    Hi #{creator.name},

    You can change your creator account email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
