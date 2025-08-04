defmodule WindowpaneWeb.ShopLive do
  use WindowpaneWeb, :live_view
  require Logger

  defmodule WalletPricing do
    @stripe_percentage_fee 0.029
    @stripe_fixed_fee 30 # cents
    @default_tax_rate 0.08

    @doc """
    Calculates the gross amount to charge in order to net the desired wallet credit
    after Stripe fees and tax.

    ## Example:
        iex> WalletPricing.calculate_gross_for_net(500)
        595

    """
    def calculate_gross_for_net(net_cents, tax_rate \\ @default_tax_rate) do
      gross = (net_cents + @stripe_fixed_fee) / (1 - tax_rate - @stripe_percentage_fee)
      gross |> Float.ceil() |> trunc()
    end
  end

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Shop", wallet_plans: add_to_wallet_plans())
      |> handle_checkout_result(params)

    {:ok, socket}
  end

  @impl true
  def handle_event("add_funds", %{"amount" => amount_str}, socket) do
    amount = String.to_integer(amount_str)
    user = socket.assigns.current_user

    case create_stripe_checkout_session(user, amount) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, reason} ->
        Logger.error("Failed to create Stripe checkout session: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to create checkout session. Please try again.")}
    end
  end

  defp add_to_wallet_plans do
    [
      %{amount: 500, display: "$5.00", label: "Add $5.00 to wallet", minimum: true},
      %{amount: 1000, display: "$10.00", label: "Add $10.00 to wallet"},
      %{amount: 2500, display: "$25.00", label: "Add $25.00 to wallet"},
      %{amount: 5000, display: "$50.00", label: "Add $50.00 to wallet"},
      %{amount: 10000, display: "$100.00", label: "Add $100.00 to wallet"}
    ]
    |> Enum.map(fn plan ->
      gross_amount = WalletPricing.calculate_gross_for_net(plan.amount)
      gross_display = "$#{gross_amount / 100 |> :erlang.float_to_binary([{:decimals, 2}])}"

      Map.merge(plan, %{
        gross_amount: gross_amount,
        gross_display: gross_display,
        estimated_total: "~#{gross_display} (est. w/ tax & fees)"
      })
    end)
  end

  defp create_stripe_checkout_session(user, net_amount_cents) do
    # Calculate the gross amount needed to net the desired wallet credit
    gross_amount_cents = WalletPricing.calculate_gross_for_net(net_amount_cents)

    try do
      Stripe.Checkout.Session.create(%{
        payment_method_types: ["card", "us_bank_account", "link", "cashapp"],
        automatic_tax: %{enabled: true},
        line_items: [
          %{
            price_data: %{
              currency: "usd",
              product_data: %{
                name: "Windowpane Wallet Funds",
                description: "Add $#{net_amount_cents / 100 |> :erlang.float_to_binary([{:decimals, 2}])} to your Windowpane wallet"
              },
              unit_amount: gross_amount_cents,
              tax_behavior: "exclusive"
            },
            quantity: 1
          }
        ],
        mode: "payment",
        customer_email: user.email,
        success_url: "#{WindowpaneWeb.Endpoint.url()}/shop?success=true",
        cancel_url: "#{WindowpaneWeb.Endpoint.url()}/shop?cancelled=true",
        metadata: %{
          user_id: user.id,
          type: "wallet_funds",
          net_amount: net_amount_cents,  # This is what gets added to wallet
          gross_amount: gross_amount_cents  # This is what gets charged
        }
      })
    rescue
      e ->
        Logger.error("Stripe checkout session creation error: #{inspect(e)}")
        {:error, :stripe_error}
    end
  end

  defp handle_checkout_result(socket, %{"success" => "true"}) do
    put_flash(socket, :info, "Payment successful! Funds will be added to your wallet shortly.")
  end

  defp handle_checkout_result(socket, %{"cancelled" => "true"}) do
    put_flash(socket, :error, "Payment was cancelled. No funds were added to your wallet.")
  end

  defp handle_checkout_result(socket, _params), do: socket

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black">
      <div class="max-w-4xl mx-auto px-4 py-8">
        <!-- Wallet Balance -->
        <%= if @current_user do %>
          <div class="mb-6 flex justify-end">
            <div class="inline-block bg-white rounded-lg px-4 py-2 shadow text-gray-800 font-semibold text-lg">
              Wallet Balance: $
              <%= Decimal.new(@current_user.wallet_balance || 0) |> Decimal.div(100) |> Decimal.round(2) |> Decimal.to_string(:normal) %>
            </div>
          </div>
        <% end %>
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-white mb-4">ADD FUNDS TO YOUR WINDOWPANE WALLET</h1>
          <div class="text-white space-y-2">
            <p>Funds in your Windowpane Wallet may be used for the rental of any content on Windowpane or within content that supports Windowpane transactions.</p>
            <p>You'll have a chance to review your order before it's placed.</p>
          </div>
        </div>

        <!-- Wallet Fund Options -->
        <div class="space-y-4">
          <%= for plan <- @wallet_plans do %>
            <div style="border: 2px solid #ffffff;" class="bg-gray-900 border-4 border-white p-6 flex items-center justify-between hover:bg-gray-900 transition-colors">
              <div>
                <h3 class="text-xl font-bold text-white"><%= plan.label %></h3>
                <p class="text-sm text-white">
                  <%= if plan[:minimum] do %>
                    Minimum fund level
                  <% end %>
                </p>
              </div>
              <div class="flex items-center space-x-4">
                <div class="text-right">
                  <div class="text-lg font-bold text-white">
                    <%= plan.display %> <span class="text-sm font-normal text-white">to wallet</span>
                  </div>
                  <div class="text-sm text-white">
                    <%= plan.estimated_total %>
                  </div>
                </div>
                <button
                  phx-click="add_funds"
                  phx-value-amount={plan.amount}
                  class="px-6 py-2 bg-gray-900 text-white border-4 border-white font-bold hover:bg-white hover:text-black transition-all duration-150 hover:scale-110"
                >
                  [add-funds]
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Success/Cancel Messages -->
        <%= if @live_action == :index do %>
          <%= if Phoenix.Flash.get(@flash, :info) do %>
            <div class="mt-6 p-4 bg-green-100 border border-green-300 rounded-lg">
              <p class="text-green-800"><%= Phoenix.Flash.get(@flash, :info) %></p>
            </div>
          <% end %>

          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="mt-6 p-4 bg-red-100 border border-red-300 rounded-lg">
              <p class="text-red-800"><%= Phoenix.Flash.get(@flash, :error) %></p>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
