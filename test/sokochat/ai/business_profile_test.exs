defmodule Sokochat.AI.BusinessProfileTest do
  use ExUnit.Case, async: true

  alias Sokochat.AI.BusinessProfile
  alias Sokochat.Workspaces.{DeliveryRate, Workspace}

  test "serializes exact delivery fees and pickup details without private fields" do
    profile =
      BusinessProfile.build(%Workspace{
        name: "Shoes",
        account_id: 42,
        ai_instructions: "Private instructions",
        pickup_enabled: true,
        location: "Shop 12",
        opening_hours: "9am to 5pm",
        map_url: "https://example.com/map",
        delivery_enabled: true,
        delivery_quote_outside: false,
        delivery_rates: [
          %DeliveryRate{area: "CBD", fee: Decimal.new("0")},
          %DeliveryRate{area: "Westlands", fee: Decimal.new("150.50")}
        ]
      })

    assert profile.pickup_enabled
    assert profile.location == "Shop 12"
    assert profile.opening_hours == "9am to 5pm"
    assert profile.map_url == "https://example.com/map"
    assert profile.delivery_enabled
    refute profile.delivery_quote_outside

    assert profile.delivery_rates == [
             %{area: "CBD", fee: "0", currency: "KES"},
             %{area: "Westlands", fee: "150.50", currency: "KES"}
           ]

    refute Map.has_key?(profile, :account_id)
    refute Map.has_key?(profile, :ai_instructions)
  end

  test "disabled delivery hides retained rates and outside quotes" do
    profile =
      BusinessProfile.build(%Workspace{
        delivery_enabled: false,
        delivery_quote_outside: true,
        delivery_rates: [%DeliveryRate{area: "CBD", fee: Decimal.new("150")}]
      })

    refute profile.delivery_enabled
    refute profile.delivery_quote_outside
    assert profile.delivery_rates == []
  end

  test "string-keyed snapshots preserve false and quote-only delivery" do
    profile =
      BusinessProfile.build(%{
        "pickup_enabled" => false,
        "delivery_enabled" => true,
        "delivery_quote_outside" => true,
        "delivery_rates" => []
      })

    assert profile.pickup_enabled == false
    assert profile.delivery_quote_outside
    assert profile.delivery_rates == []
    assert BusinessProfile.build(%{}).delivery_enabled == nil
  end
end
