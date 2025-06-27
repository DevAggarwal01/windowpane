defmodule WindowpaneWeb.Plugs.RawBodyPlug do
  @moduledoc """
  A plug to preserve the raw request body for webhook verification.
  This is needed for Stripe webhooks which require the original raw body
  for signature verification.

  This plug is intentionally ONLY applied to Stripe webhooks to avoid
  interfering with other webhook systems like Mux that need normal JSON parsing.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only read the body for Stripe webhook endpoints
    if stripe_webhook_endpoint?(conn) do
      case read_body(conn) do
        {:ok, body, conn} ->
          conn
          |> assign(:raw_body, body)
          |> put_private(:plug_body_reader, {__MODULE__, :cache_body, [body]})

        {:error, _reason} ->
          conn
      end
    else
      conn
    end
  end

  def cache_body(conn, _opts) do
    body = conn.assigns[:raw_body] || ""
    {:ok, body, conn}
  end

  defp stripe_webhook_endpoint?(conn) do
    conn.request_path == "/stripe/webhook"
  end
end
