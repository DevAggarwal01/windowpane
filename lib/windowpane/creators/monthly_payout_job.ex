defmodule Windowpane.Creators.MonthlyPayoutJob do
  @moduledoc """
  Oban job that processes monthly payouts for creators.

  Runs on the 15th of every month at 6:00 AM UTC.
  Processes all creators with wallet balance >= $50 (5000 cents) and
  initiates payouts using Stripe Connect.

  Stripe fees (2.9% + $0.30) are deducted from the payout amount.
  """

  use Oban.Worker, queue: :payouts, max_attempts: 3

  require Logger

  alias Windowpane.Repo
  alias Windowpane.Creators.Creator
  import Ecto.Query

  @minimum_payout_cents 5000  # $50 in cents
  @stripe_percentage_fee 0.029  # 2.9%
  @stripe_fixed_fee_cents 30    # $0.30 in cents

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting monthly payout job")

    creators_with_sufficient_balance()
    |> Enum.each(&process_creator_payout/1)

    Logger.info("Monthly payout job completed")
    :ok
  end

  defp creators_with_sufficient_balance do
    from(c in Creator,
      where: c.wallet_balance >= @minimum_payout_cents,
      where: not is_nil(c.stripe_account_id)
    )
    |> Repo.all()
  end

  defp process_creator_payout(%Creator{} = creator) do
    net_amount = calculate_net_amount(creator.wallet_balance)

    Logger.info(
      "Processing payout for creator #{creator.id} with balance #{creator.wallet_balance} cents, net amount #{net_amount} cents"
    )

    case initiate_stripe_payout(creator, net_amount) do
      {:ok, transfer} ->
        handle_successful_payout(creator, transfer, net_amount)

      {:error, error} ->
        handle_failed_payout(creator, error)
    end
  end

  defp calculate_net_amount(wallet_balance_cents) do
    # net_amount = wallet_balance * 0.971 - 0.30
    # This accounts for Stripe's 2.9% + $0.30 fee
    net_amount = (wallet_balance_cents * (1 - @stripe_percentage_fee)) - @stripe_fixed_fee_cents

    # Round to nearest cent and ensure it's not negative
    max(0, round(net_amount))
  end

  defp initiate_stripe_payout(%Creator{stripe_account_id: account_id}, net_amount) do
    Stripe.Transfer.create(%{
      amount: net_amount,
      currency: "usd",
      destination: account_id
    })
  end

  defp handle_successful_payout(%Creator{} = creator, transfer, net_amount) do
    Logger.info("Payout successful for creator #{creator.id}. Transfer ID: #{transfer.id}, Net amount: #{net_amount} cents")

    # Reset wallet balance to 0
    creator
    |> Creator.update_changeset(%{wallet_balance: 0})
    |> Repo.update()
    |> case do
      {:ok, updated_creator} ->
        log_payout_transaction(updated_creator, transfer, :success, net_amount)
        Logger.info("Wallet balance reset for creator #{creator.id}")

      {:error, changeset} ->
        Logger.error("Failed to reset wallet balance for creator #{creator.id}: #{inspect(changeset.errors)}")
    end
  end

  defp handle_failed_payout(%Creator{} = creator, error) do
    Logger.error("Payout failed for creator #{creator.id}: #{inspect(error)}")
    log_payout_transaction(creator, nil, :failed, 0, error)
  end

  defp log_payout_transaction(creator, transfer, status, net_amount, error \\ nil) do
    stripe_fee = creator.wallet_balance - net_amount

    log_data = %{
      creator_id: creator.id,
      gross_amount_cents: creator.wallet_balance,
      net_amount_cents: net_amount,
      stripe_fee_cents: stripe_fee,
      status: status,
      timestamp: DateTime.utc_now(),
      transfer_id: transfer && transfer.id,
      stripe_account_id: creator.stripe_account_id
    }

    log_data = if error, do: Map.put(log_data, :error, inspect(error)), else: log_data

    Logger.info("Payout transaction logged: #{inspect(log_data)}")
  end
end
