defmodule WindowpaneWeb.StripeWebhookController do
  use WindowpaneWeb, :controller
  require Logger

  def create(conn, _params) do
    # Get the raw body from assigns (set by RawBodyPlug)
    raw_body = conn.assigns[:raw_body]
    sig_header = get_req_header(conn, "stripe-signature") |> List.first()
    endpoint_secret = Application.get_env(:windowpane, :stripe_webhook_secret)

    cond do
      is_nil(raw_body) or raw_body == "" ->
        Logger.error("Stripe webhook: No raw body available")
        send_resp(conn, 400, "No request body")

      is_nil(sig_header) ->
        Logger.error("Stripe webhook: Missing stripe-signature header")
        send_resp(conn, 400, "Missing signature header")

      is_nil(endpoint_secret) ->
        Logger.error("Stripe webhook: STRIPE_WEBHOOK_SECRET not configured")
        send_resp(conn, 500, "Webhook secret not configured")

      true ->
        case verify_webhook_signature(raw_body, sig_header, endpoint_secret) do
          {:ok, event} ->
            handle_stripe_event(event)
            send_resp(conn, 200, "OK")

          {:error, reason} ->
            Logger.error("Stripe webhook verification failed: #{inspect(reason)}")
            send_resp(conn, 400, "Webhook signature verification failed")
        end
    end
  end

  defp verify_webhook_signature(payload, sig_header, endpoint_secret) do
    try do
      Logger.debug("Verifying webhook with payload length: #{byte_size(payload)}")

      case Stripe.Webhook.construct_event(payload, sig_header, endpoint_secret) do
        {:ok, event} ->
          Logger.debug("Webhook verification successful")
          {:ok, event}
        {:error, reason} ->
          Logger.warning("Stripe webhook verification failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error verifying Stripe webhook: #{inspect(e)}")
        {:error, :verification_failed}
    end
  end

  defp handle_stripe_event(%Stripe.Event{type: event_type, data: %{object: event_data}} = event) do
    Logger.info("Received Stripe webhook event: #{event_type}")

    case event_type do
      "checkout.session.completed" ->
        handle_checkout_session_completed(event_data)

      "checkout.session.async_payment_succeeded" ->
        handle_async_payment_succeeded(event_data)

      _ ->
        Logger.info("Unhandled Stripe webhook event type: #{event_type}")
        :ok
    end
  end

  defp handle_checkout_session_completed(%Stripe.Checkout.Session{} = session) do
    Logger.info("Checkout session completed: #{session.id}")

    # Extract metadata from the session
    metadata = session.metadata || %{}

    case metadata do
      %{"user_id" => user_id, "type" => "wallet_funds", "amount" => amount} ->
        # Handle wallet funds addition
        process_wallet_funds_transaction(user_id, amount, session)

      _ ->
        Logger.warning("Checkout session completed but missing required metadata: #{inspect(metadata)}")
    end
  end

  defp handle_async_payment_succeeded(%Stripe.Checkout.Session{} = session) do
    Logger.info("Async payment succeeded for session: #{session.id}")

    # Extract metadata from the session
    metadata = session.metadata || %{}

    case metadata do
      %{"project_id" => project_id, "user_id" => user_id, "type" => type} ->
        # Handle film rental or purchase
        process_film_transaction(project_id, user_id, type, session)

      %{"user_id" => user_id, "type" => "wallet_funds", "amount" => amount} ->
        # Handle wallet funds addition
        process_wallet_funds_transaction(user_id, amount, session)

      _ ->
        Logger.warning("Async payment succeeded but missing required metadata: #{inspect(metadata)}")
    end
  end

  defp process_film_transaction(project_id, user_id, type, payment_intent) do
    Logger.info("Processing #{type} for project #{project_id}, user #{user_id}")

    # TODO: Implement the actual business logic
    # This would typically involve:
    # 1. Creating a rental record
    # 2. Granting access to the user
    # 3. Sending confirmation email
    # 4. Updating user's library

    case type do
      "rental" ->
        Logger.info("Creating rental record for project #{project_id}")
        # Windowpane.Purchases.create_rental(user_id, project_id, payment_intent)

      _ ->
        Logger.warning("Unknown transaction type: #{type}")
    end
  end

  defp process_wallet_funds_transaction(user_id, amount, payment_intent) do
    Logger.info("Processing wallet funds transaction for user #{user_id}, amount: #{amount}")

    # Convert amount from string to integer if needed
    amount_cents = case amount do
      amount when is_binary(amount) -> String.to_integer(amount)
      amount when is_integer(amount) -> amount
    end

    # Add funds to user's wallet
    case Windowpane.Accounts.add_wallet_funds(user_id, amount_cents) do
      {:ok, user} ->
        Logger.info("Successfully added #{amount_cents} cents to user #{user_id} wallet. New balance: #{user.wallet_balance}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to add wallet funds for user #{user_id}: #{inspect(reason)}")
        :error
    end
  end
end
