defmodule Windowpane.Creators.PayoutHelpers do
  @moduledoc """
  Helper functions for managing and testing monthly payouts.

  This module provides utilities for:
  - Manually triggering payout jobs for testing
  - Checking which creators are eligible for payouts
  - Viewing payout job status
  """

  alias Windowpane.Repo
  alias Windowpane.Creators.Creator
  alias Windowpane.Creators.MonthlyPayoutJob
  import Ecto.Query

  @minimum_payout_cents 5000  # $50 in cents
  @stripe_percentage_fee 0.029  # 2.9%
  @stripe_fixed_fee_cents 30    # $0.30 in cents

  @doc """
  Calculate net amount after Stripe fees (2.9% + $0.30).
  """
  def calculate_net_amount(wallet_balance_cents) do
    net_amount = (wallet_balance_cents * (1 - @stripe_percentage_fee)) - @stripe_fixed_fee_cents
    max(0, round(net_amount))
  end

  @doc """
  Calculate Stripe fee for a given wallet balance.
  """
  def calculate_stripe_fee(wallet_balance_cents) do
    wallet_balance_cents - calculate_net_amount(wallet_balance_cents)
  end

  @doc """
  Manually trigger a monthly payout job.
  Useful for testing in development.
  """
  def trigger_manual_payout do
    %{}
    |> MonthlyPayoutJob.new(queue: :payouts)
    |> Oban.insert()
  end

  @doc """
  Get all creators eligible for payout (balance >= $50 with Stripe account).
  """
  def eligible_creators do
    from(c in Creator,
      where: c.wallet_balance >= @minimum_payout_cents,
      where: not is_nil(c.stripe_account_id),
      select: %{
        id: c.id,
        name: c.name,
        email: c.email,
        wallet_balance: c.wallet_balance,
        stripe_account_id: c.stripe_account_id
      }
    )
    |> Repo.all()
    |> Enum.map(fn creator ->
      net_amount = calculate_net_amount(creator.wallet_balance)
      stripe_fee = calculate_stripe_fee(creator.wallet_balance)

      Map.merge(creator, %{
        net_amount: net_amount,
        stripe_fee: stripe_fee
      })
    end)
  end

  @doc """
  Get summary of wallet balances across all creators.
  """
  def wallet_summary do
    total_eligible = from(c in Creator,
      where: c.wallet_balance >= @minimum_payout_cents,
      where: not is_nil(c.stripe_account_id),
      select: %{
        count: count(c.id),
        total_balance: sum(c.wallet_balance)
      }
    )
    |> Repo.one()

    all_creators = from(c in Creator,
      select: %{
        count: count(c.id),
        total_balance: sum(c.wallet_balance)
      }
    )
    |> Repo.one()

    # Calculate net amounts for eligible creators
    eligible_net_amount = if total_eligible.total_balance do
      calculate_net_amount(total_eligible.total_balance)
    else
      0
    end

    eligible_stripe_fee = if total_eligible.total_balance do
      calculate_stripe_fee(total_eligible.total_balance)
    else
      0
    end

    %{
      eligible_for_payout: Map.merge(total_eligible, %{
        total_net_amount: eligible_net_amount,
        total_stripe_fee: eligible_stripe_fee
      }),
      all_creators: all_creators,
      minimum_payout_dollars: @minimum_payout_cents / 100,
      stripe_fee_info: %{
        percentage: @stripe_percentage_fee * 100,
        fixed_fee_cents: @stripe_fixed_fee_cents
      }
    }
  end

  @doc """
  Check recent payout job executions from Oban.
  """
  def recent_payout_jobs(limit \\ 10) do
    from(j in Oban.Job,
      where: j.worker == "Windowpane.Creators.MonthlyPayoutJob",
      order_by: [desc: j.inserted_at],
      limit: ^limit,
      select: %{
        id: j.id,
        state: j.state,
        inserted_at: j.inserted_at,
        scheduled_at: j.scheduled_at,
        attempted_at: j.attempted_at,
        completed_at: j.completed_at,
        errors: j.errors
      }
    )
    |> Repo.all()
  end

  @doc """
  Create test creators with various wallet balances for testing.
  Only works in development environment.
  """
  def create_test_creators do
    if Mix.env() == :dev do
      test_creators = [
        %{
          name: "Test Creator 1",
          email: "test1@example.com",
          wallet_balance: 7500,  # $75
          stripe_account_id: "acct_test_123"
        },
        %{
          name: "Test Creator 2",
          email: "test2@example.com",
          wallet_balance: 3000,  # $30 - below minimum
          stripe_account_id: "acct_test_456"
        },
        %{
          name: "Test Creator 3",
          email: "test3@example.com",
          wallet_balance: 10000, # $100
          stripe_account_id: nil  # No Stripe account
        }
      ]

      Enum.each(test_creators, fn attrs ->
        %Creator{}
        |> Creator.update_changeset(attrs)
        |> Repo.insert()
      end)

      IO.puts("Created test creators for payout testing")
    else
      IO.puts("Test creators can only be created in development environment")
    end
  end
end
