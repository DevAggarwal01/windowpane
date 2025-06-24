defmodule Windowpane.PricingCalculator do
  @moduledoc """
  Pricing calculator module for video streaming services.
  Contains functions to calculate platform margins, creator cuts, and revenue breakdowns.
  """

  @doc """
  Calculate the platform margin percentage based on price using the decreasing marginal fee structure.

  The formula is: platform_margin(P) = 0.4 / (P + 1) + 0.1

  Args:
    price (float): The ticket price in USD

  Returns:
    float: The platform margin percentage (between 0 and 1)
  """
  def calculate_platform_margin_percent(price) when is_number(price) and price > 0 do
    0.4 / (price + 1) + 0.1
  end
  def calculate_platform_margin_percent(_), do: 0.0

  @doc """
  Calculate the creator cut for a given price.

  Args:
    price (float): The ticket price in USD

  Returns:
    float: The creator cut amount in USD
  """
  def calculate_creator_cut(price) when is_number(price) and price > 0 do
    platform_margin = calculate_platform_margin_percent(price)
    platform_cut = price * platform_margin
    price - platform_cut
  end
  def calculate_creator_cut(_), do: 0.0

  @doc """
  Calculate the complete revenue breakdown for a given price.

  Args:
    price (float): The ticket price in USD

  Returns:
    map: A map containing price, platform_margin, platform_cut, and creator_payout
  """
  def calculate_revenue_breakdown(price) when is_number(price) and price >= 0 do
    platform_margin = calculate_platform_margin_percent(price)
    platform_cut = price * platform_margin
    creator_payout = price - platform_cut

    %{
      price: price,
      platform_margin: platform_margin,
      platform_cut: platform_cut,
      creator_payout: creator_payout
    }
  end
  def calculate_revenue_breakdown(_), do: %{price: 0.0, platform_margin: 0.0, platform_cut: 0.0, creator_payout: 0.0}

  @doc """
  Helper function to convert various price formats to float.

  Args:
    price: The price in various formats (string, Decimal, float, integer)

  Returns:
    float: The price as a float
  """
  def normalize_price(price) when is_binary(price) do
    case Float.parse(price) do
      {float_price, _} -> float_price
      :error -> 0.0
    end
  end
  def normalize_price(%Decimal{} = price), do: Decimal.to_float(price)
  def normalize_price(price) when is_float(price), do: price
  def normalize_price(price) when is_integer(price), do: price * 1.0
  def normalize_price(_), do: 0.0
end
