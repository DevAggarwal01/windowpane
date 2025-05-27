defmodule AuroraWeb.StripeWebhookController do
  use AuroraWeb, :controller

  alias Stripe.Event
  alias Aurora.Accounts  # or wherever your user/subscription logic lives

  @endpoint_secret System.fetch_env!("STRIPE_WEBHOOK_SECRET")

  def handle(conn, _params) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    sig_header = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()

    with {:ok, %Event{} = event} <- Stripe.Webhook.construct_event(body, sig_header, @endpoint_secret) do
      handle_event(event)
      send_resp(conn, 200, "Received")
    else
      _ -> send_resp(conn, 400, "Invalid signature")
    end
  end

  defp handle_event(%Event{type: "checkout.session.completed", data: %{object: session}}) do
    IO.puts("✅ Checkout completed: #{session.id}")
    # Lookup user via session.customer_email or metadata and mark as subscribed
    plan = session.metadata["plan_id"]
    user_id = session.metadata["user_id"]
    Accounts.mark_user_subscribed(user_id, plan)
  end

  defp handle_event(%Event{type: "invoice.payment_failed"} = event) do
    IO.puts("⚠️ Payment failed for: #{event.data.object.customer}")
    # Mark user as delinquent
  end

  defp handle_event(event) do
    IO.puts("Unhandled event type: #{event.type}")
  end
end
