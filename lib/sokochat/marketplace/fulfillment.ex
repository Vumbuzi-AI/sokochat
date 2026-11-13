defmodule Sokochat.Marketplace.Fulfillment do
  @moduledoc "Seller-defined fulfilment choices and fee snapshots. Amounts never come from the model."
  alias Sokochat.{Repo, Workspaces.Workspace}

  def shop(order), do: Repo.get!(Workspace, order.workspace_id)
  def configured?(shop), do: shop.pickup_enabled || shop.delivery_enabled

  def build_quote(shop, "pickup") do
    if shop.pickup_enabled && shop.location not in [nil, ""],
      do:
        {:ok,
         %{
           "method" => "pickup",
           "fee" => "0",
           "pickup_address" => shop.location,
           "opening_hours" => shop.opening_hours,
           "map_url" => shop.map_url
         }},
      else: {:error, :unavailable}
  end

  def build_quote(shop, "other") do
    if shop.delivery_enabled && shop.delivery_quote_outside,
      do:
        {:ok,
         %{
           "method" => "delivery",
           "area" => "Other area",
           "fee" => nil,
           "rate_id" => "other",
           "awaiting_address" => true
         }},
      else: {:error, :unavailable}
  end

  def build_quote(shop, "merchant") do
    if !configured?(shop),
      do: {:ok, %{"method" => "merchant", "fee" => nil}},
      else: {:error, :unavailable}
  end

  def build_quote(shop, rate_id) do
    case Enum.find(shop.delivery_rates, &(&1.id == rate_id)) do
      rate when not is_nil(rate) and shop.delivery_enabled ->
        {:ok,
         %{
           "method" => "delivery",
           "area" => rate.area,
           "fee" => Decimal.to_string(rate.fee),
           "rate_id" => rate.id,
           "awaiting_address" => true
         }}

      _ ->
        {:error, :unavailable}
    end
  end

  def valid?(shop, %{"method" => method} = saved) do
    key =
      case method do
        "delivery" -> saved["rate_id"]
        "pickup" -> "pickup"
        "merchant" -> "merchant"
        _ -> nil
      end

    with true <- is_binary(key), {:ok, current} <- build_quote(shop, key) do
      keys = ~w(method area fee rate_id pickup_address opening_hours map_url)

      Map.take(saved, keys) == Map.take(current, keys) &&
        (method != "delivery" ||
           (saved["awaiting_address"] == false && is_binary(saved["address"]) &&
              String.trim(saved["address"]) != ""))
    else
      _ -> false
    end
  end

  def valid?(_, _), do: false

  def summary(nil), do: "Collection or delivery to confirm with seller."

  def summary(%{"method" => "pickup"} = details) do
    [
      "Collect in store: #{details["pickup_address"]}",
      details["opening_hours"],
      details["map_url"]
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  def summary(%{"method" => "delivery"} = details) do
    fee =
      if details["fee"],
        do: "KES #{details["fee"]}",
        else: "Delivery fee to be confirmed by the seller"

    ["Delivery: #{details["area"]} · #{fee}", details["address"]]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  def summary(_), do: "Collection, delivery and any charges to confirm with seller."
end
