defmodule WindowpaneWeb.WalletLive do
  use WindowpaneWeb, :live_view
  import WindowpaneWeb.NavComponents

  alias Windowpane.{Accounts, Creators}

  @impl true
  def mount(_params, _session, socket) do
    cond do
      # Check if this is a creator request (studio.windowpane.tv)
      socket.assigns[:current_creator] ->
        creator = socket.assigns.current_creator
        wallet_balance = creator.wallet_balance
        user_type = :creator

        {:ok, assign(socket,
          wallet_balance: wallet_balance,
          user_type: user_type,
          user: creator,
          page_title: "Wallet"
        )}

      # Check if this is a user request (windowpane.tv)
      socket.assigns[:current_user] ->
        user = socket.assigns.current_user
        wallet_balance = user.wallet_balance
        user_type = :user

        {:ok, assign(socket,
          wallet_balance: wallet_balance,
          user_type: user_type,
          user: user,
          page_title: "Wallet"
        )}

      # No authenticated user found
      true ->
        {:ok, socket
        |> put_flash(:error, "You must be logged in to view your wallet.")
        |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("view_transaction_history", _params, socket) do
    cond do
      # Only creators can access Stripe dashboard
      socket.assigns.user_type == :creator ->
        creator = socket.assigns.user

        case creator.stripe_account_id do
          nil ->
            {:noreply, socket
            |> put_flash(:error, "Stripe account not configured. Please complete your onboarding.")}

          stripe_account_id ->
            case Stripe.LoginLink.create(stripe_account_id) do
              {:ok, %Stripe.LoginLink{url: url}} ->
                {:noreply, socket
                |> push_event("open_external_url", %{url: url})}

              {:error, _error} ->
                {:noreply, socket
                |> put_flash(:error, "Unable to access transaction history. Please try again later.")}
            end
        end

      # Users don't have access to Stripe dashboard
      socket.assigns.user_type == :user ->
        {:noreply, socket
        |> put_flash(:info, "Transaction history coming soon for users.")}

      # Fallback
      true ->
        {:noreply, socket
        |> put_flash(:error, "You must be logged in to view transaction history.")}
    end
  end

  # Helper function to format wallet balance
  def format_wallet_balance(balance_cents) when is_integer(balance_cents) do
    dollars = balance_cents / 100.0
    "$#{:erlang.float_to_binary(dollars, [{:decimals, 2}])}"
  end

  def format_wallet_balance(nil), do: "$0.00"
end
