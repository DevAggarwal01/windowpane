defmodule Aurora.Creators do
  @moduledoc """
  The Creators context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Aurora.Repo

  alias Aurora.Creators.{Creator, CreatorToken, CreatorNotifier, CreatorCode}

  ## Database getters

  @doc """
  Gets a creator by email.

  ## Examples

      iex> get_creator_by_email("foo@example.com")
      %Creator{}

      iex> get_creator_by_email("unknown@example.com")
      nil

  """
  def get_creator_by_email(email) when is_binary(email) do
    Repo.get_by(Creator, email: email)
  end

  @doc """
  Gets a creator by email and password.

  ## Examples

      iex> get_creator_by_email_and_password("foo@example.com", "correct_password")
      %Creator{}

      iex> get_creator_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_creator_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    creator = Repo.get_by(Creator, email: email)
    if Creator.valid_password?(creator, password), do: creator
  end

  @doc """
  Gets a single creator.

  Raises `Ecto.NoResultsError` if the Creator does not exist.

  ## Examples

      iex> get_creator!(123)
      %Creator{}

      iex> get_creator!(456)
      ** (Ecto.NoResultsError)

  """
  def get_creator!(id), do: Repo.get!(Creator, id)

  ## Creator registration

  @doc """
  Registers a creator.

  ## Examples

      iex> register_creator(%{field: value})
      {:ok, %Creator{}}

      iex> register_creator(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_creator(attrs) do
    creator_code = Map.get(attrs, "creator_code")

    if valid_creator_code?(creator_code) do
      %Creator{}
      |> Creator.registration_changeset(attrs)
      |> Repo.insert()
    else
      {:error,
        %Creator{}
        |> Creator.registration_changeset(attrs)
        |> Ecto.Changeset.add_error(:creator_code, "is invalid")}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking creator changes.

  ## Examples

      iex> change_creator_registration(creator)
      %Ecto.Changeset{data: %Creator{}}

  """
  def change_creator_registration(%Creator{} = creator, attrs \\ %{}) do
    Creator.registration_changeset(creator, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the creator email.

  ## Examples

      iex> change_creator_email(creator)
      %Ecto.Changeset{data: %Creator{}}

  """
  def change_creator_email(creator, attrs \\ %{}) do
    Creator.email_changeset(creator, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_creator_email(creator, "valid password", %{email: ...})
      {:ok, %Creator{}}

      iex> apply_creator_email(creator, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_creator_email(creator, password, attrs) do
    creator
    |> Creator.email_changeset(attrs)
    |> Creator.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the creator email using the given token.

  If the token matches, the creator email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_creator_email(creator, token) do
    context = "change:#{creator.email}"

    with {:ok, query} <- CreatorToken.verify_change_email_token_query(token, context),
         %CreatorToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(creator_email_multi(creator, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp creator_email_multi(creator, email, context) do
    changeset =
      creator
      |> Creator.email_changeset(%{email: email})
      |> Creator.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:creator, changeset)
    |> Ecto.Multi.delete_all(:tokens, CreatorToken.by_creator_and_contexts_query(creator, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given creator.

  ## Examples

      iex> deliver_creator_update_email_instructions(creator, current_email, &url(~p"/creators/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_creator_update_email_instructions(%Creator{} = creator, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, creator_token} = CreatorToken.build_email_token(creator, "change:#{current_email}")

    Repo.insert!(creator_token)
    CreatorNotifier.deliver_update_email_instructions(creator, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the creator password.

  ## Examples

      iex> change_creator_password(creator)
      %Ecto.Changeset{data: %Creator{}}

  """
  def change_creator_password(creator, attrs \\ %{}) do
    Creator.password_changeset(creator, attrs, hash_password: false)
  end

  @doc """
  Updates the creator password.

  ## Examples

      iex> update_creator_password(creator, "valid password", %{password: ...})
      {:ok, %Creator{}}

      iex> update_creator_password(creator, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_creator_password(creator, password, attrs) do
    changeset =
      creator
      |> Creator.password_changeset(attrs)
      |> Creator.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:creator, changeset)
    |> Ecto.Multi.delete_all(:tokens, CreatorToken.by_creator_and_contexts_query(creator, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{creator: creator}} -> {:ok, creator}
      {:error, :creator, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_creator_session_token(creator) do
    {token, creator_token} = CreatorToken.build_session_token(creator)
    Repo.insert!(creator_token)
    token
  end

  @doc """
  Gets the creator with the given signed token.
  """
  def get_creator_by_session_token(token) do
    {:ok, query} = CreatorToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_creator_session_token(token) do
    Repo.delete_all(CreatorToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given creator.

  ## Examples

      iex> deliver_creator_confirmation_instructions(creator, &url(~p"/creators/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_creator_confirmation_instructions(confirmed_creator, &url(~p"/creators/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_creator_confirmation_instructions(%Creator{} = creator, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if creator.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, creator_token} = CreatorToken.build_email_token(creator, "confirm")
      Repo.insert!(creator_token)
      CreatorNotifier.deliver_confirmation_instructions(creator, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a creator by the given token.

  If the token matches, the creator account is marked as confirmed
  and the token is deleted.
  """
  def confirm_creator(token) do
    with {:ok, query} <- CreatorToken.verify_email_token_query(token, "confirm"),
         %Creator{} = creator <- Repo.one(query),
         {:ok, %{creator: creator}} <- Repo.transaction(confirm_creator_multi(creator)) do
      {:ok, creator}
    else
      _ -> :error
    end
  end

  defp confirm_creator_multi(creator) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:creator, Creator.confirm_changeset(creator))
    |> Ecto.Multi.delete_all(:tokens, CreatorToken.by_creator_and_contexts_query(creator, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given creator.

  ## Examples

      iex> deliver_creator_reset_password_instructions(creator, &url(~p"/creators/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_creator_reset_password_instructions(%Creator{} = creator, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, creator_token} = CreatorToken.build_email_token(creator, "reset_password")
    Repo.insert!(creator_token)
    CreatorNotifier.deliver_reset_password_instructions(creator, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the creator by reset password token.

  ## Examples

      iex> get_creator_by_reset_password_token("validtoken")
      %Creator{}

      iex> get_creator_by_reset_password_token("invalidtoken")
      nil

  """
  def get_creator_by_reset_password_token(token) do
    with {:ok, query} <- CreatorToken.verify_email_token_query(token, "reset_password"),
         %Creator{} = creator <- Repo.one(query) do
      creator
    else
      _ -> nil
    end
  end

  @doc """
  Resets the creator password.

  ## Examples

      iex> reset_creator_password(creator, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Creator{}}

      iex> reset_creator_password(creator, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_creator_password(creator, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:creator, Creator.password_changeset(creator, attrs))
    |> Ecto.Multi.delete_all(:tokens, CreatorToken.by_creator_and_contexts_query(creator, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{creator: creator}} -> {:ok, creator}
      {:error, :creator, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Validates if a creator code exists.
  Returns true if the code is valid, false otherwise.
  """
  def valid_creator_code?(code) when is_binary(code) do
    case Repo.get_by(CreatorCode, code: code) do
      nil -> false
      _code -> true
    end
  end

  @doc """
  Fetches all Stripe products that start with "Creator's Plan" and their associated prices.
  Returns a list of maps containing product and price information, sorted by price.
  """
  def fetch_creator_plans do
    Logger.info("fetch_creator_plans called")
    free_plan = %{
      id: "free",
      name: "Free",
      description: "You can look around, but nothing else!",
      price: 0,
      price_id: "free"
    }

    case Application.get_env(:stripity_stripe, :api_key) do
      nil ->
        Logger.warning("No Stripe API key configured")
        [free_plan]
      _ ->
        try do
          {:ok, products} = Stripe.Product.list(%{active: true})
          Logger.info("Stripe product successfully fetched: #{inspect(products.data)}")
          stripe_plans = products.data
          |> Enum.filter(&String.starts_with?(&1.name, "Creator's Plan"))
          |> Enum.map(fn product ->
            {:ok, prices} = Stripe.Price.list(%{product: product.id, active: true})
            price = List.first(prices.data)
            %{
              id: product.id,
              name: product.name,
              description: product.description,
              price: price.unit_amount / 100, # Convert cents to dollars
              price_id: price.id
            }
          end)

          # Combine free plan with stripe plans and sort by price
          ([free_plan | stripe_plans]
          |> Enum.sort_by(& &1.price))
        rescue
          e ->
            # Log the error and return empty list if Stripe API call fails
            Logger.error("Error fetching creator plans: #{inspect(e)}")
            []
        end
    end
  end

  @doc """
  Updates a creator with the given attributes.

  ## Examples

      iex> update_creator(creator, %{field: new_value})
      {:ok, %Creator{}}

      iex> update_creator(creator, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_creator(%Creator{} = creator, attrs) do
    creator
    |> Creator.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a list of all creator accounts.
  """
  def list_creators do
    Repo.all(Creator)
  end

  def search_creators(search_term) when is_binary(search_term) and search_term != "" do
    search_pattern = "%#{search_term}%"

    Creator
    |> where([c], like(c.email, ^search_pattern))
    |> Repo.all()
  end

  def search_creators(_), do: list_creators()

  @doc """
  Deletes a creator account.

  ## Examples

      iex> delete_creator(creator)
      {:ok, %Creator{}}

      iex> delete_creator(creator)
      {:error, %Ecto.Changeset{}}

  """
  def delete_creator(%{type: "creator"} = creator_data) do
    creator = Repo.get_by(Creator, uid: creator_data.uid)
    if creator do
      # TODO: Add any cleanup needed (e.g., Stripe account deletion)
      Repo.delete(creator)
    else
      {:error, :not_found}
    end
  end

  def delete_creator(%Creator{} = creator) do
    # TODO: Add any cleanup needed (e.g., Stripe account deletion)
    Repo.delete(creator)
  end

  def delete_creator(_), do: {:error, :invalid_creator}
end
