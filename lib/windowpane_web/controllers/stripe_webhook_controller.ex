defmodule WindowpaneWeb.StripeWebhookController do
  use WindowpaneWeb, :controller
  require Logger

  def create(conn, _params) do
    {:ok, payload, _conn} = Plug.Conn.read_body(conn)
    sig_header = get_req_header(conn, "stripe-signature") |> List.first()
    endpoint_secret = Application.get_env(:windowpane, :stripe_webhook_secret)

    case verify_webhook_signature(payload, sig_header, endpoint_secret) do
      {:ok, event} ->
        handle_stripe_event(event)
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Stripe webhook verification failed: #{inspect(reason)}")
        send_resp(conn, 400, "Webhook signature verification failed")
    end
  end

  defp verify_webhook_signature(payload, sig_header, endpoint_secret) do
    try do
      case Stripe.Webhook.construct_event(payload, sig_header, endpoint_secret) do
        {:ok, event} -> {:ok, event}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error verifying Stripe webhook: #{inspect(e)}")
        {:error, :verification_failed}
    end
  end

  defp handle_stripe_event(%{"type" => event_type} = event) do
    Logger.info("Received Stripe webhook event: #{event_type}")

    case event_type do
      "payment_intent.succeeded" ->
        handle_payment_succeeded(event["data"]["object"])

      "payment_intent.payment_failed" ->
        handle_payment_failed(event["data"]["object"])

      "invoice.payment_succeeded" ->
        handle_invoice_payment_succeeded(event["data"]["object"])

      "customer.subscription.created" ->
        handle_subscription_created(event["data"]["object"])

      "customer.subscription.updated" ->
        handle_subscription_updated(event["data"]["object"])

      "customer.subscription.deleted" ->
        handle_subscription_deleted(event["data"]["object"])

      _ ->
        Logger.info("Unhandled Stripe webhook event type: #{event_type}")
        :ok
    end
  end

  defp handle_payment_succeeded(payment_intent) do
    Logger.info("Payment succeeded: #{payment_intent["id"]}")

    # Extract metadata to identify the purchase
    metadata = payment_intent["metadata"] || %{}

    case metadata do
      %{"project_id" => project_id, "user_id" => user_id, "type" => type} ->
        # Handle film rental or purchase
        process_film_transaction(project_id, user_id, type, payment_intent)

      _ ->
        Logger.warning("Payment succeeded but missing required metadata: #{inspect(metadata)}")
    end
  end

  defp handle_payment_failed(payment_intent) do
    Logger.warning("Payment failed: #{payment_intent["id"]}")

    # You might want to notify the user or update order status
    metadata = payment_intent["metadata"] || %{}
    Logger.info("Failed payment metadata: #{inspect(metadata)}")
  end

  defp handle_invoice_payment_succeeded(invoice) do
    Logger.info("Invoice payment succeeded: #{invoice["id"]}")

    # Handle subscription payments
    subscription_id = invoice["subscription"]
    if subscription_id do
      Logger.info("Subscription payment succeeded: #{subscription_id}")
      # Update subscription status, extend access, etc.
    end
  end

  defp handle_subscription_created(subscription) do
    Logger.info("Subscription created: #{subscription["id"]}")

    # Handle new subscription creation
    customer_id = subscription["customer"]
    Logger.info("New subscription for customer: #{customer_id}")
  end

  defp handle_subscription_updated(subscription) do
    Logger.info("Subscription updated: #{subscription["id"]}")

    # Handle subscription changes (plan changes, etc.)
    status = subscription["status"]
    Logger.info("Subscription status: #{status}")
  end

  defp handle_subscription_deleted(subscription) do
    Logger.info("Subscription deleted: #{subscription["id"]}")

    # Handle subscription cancellation
    customer_id = subscription["customer"]
    Logger.info("Subscription cancelled for customer: #{customer_id}")
  end

  defp process_film_transaction(project_id, user_id, type, payment_intent) do
    Logger.info("Processing #{type} for project #{project_id}, user #{user_id}")

    # TODO: Implement the actual business logic
    # This would typically involve:
    # 1. Creating a purchase/rental record
    # 2. Granting access to the user
    # 3. Sending confirmation email
    # 4. Updating user's library

    case type do
      "rental" ->
        Logger.info("Creating rental record for project #{project_id}")
        # Windowpane.Purchases.create_rental(user_id, project_id, payment_intent)

      "purchase" ->
        Logger.info("Creating purchase record for project #{project_id}")
        # Windowpane.Purchases.create_purchase(user_id, project_id, payment_intent)

      _ ->
        Logger.warning("Unknown transaction type: #{type}")
    end
  end
end
