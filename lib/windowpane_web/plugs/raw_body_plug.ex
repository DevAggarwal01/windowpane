defmodule WindowpaneWeb.Plugs.RawBodyPlug do
  @moduledoc """
  A plug to preserve the raw request body for webhook verification.
  This is needed for Stripe webhooks which require the original raw body
  for signature verification.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only read the body for webhook endpoints
    if webhook_endpoint?(conn) do
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

  defp webhook_endpoint?(conn) do
    conn.request_path in ["/stripe/webhook", "/mux/webhook"]
  end
end
