defmodule Sokochat.FulfillmentTest do
  use ExUnit.Case, async: true
  alias Sokochat.Marketplace.Fulfillment
  alias Sokochat.Workspaces.{DeliveryRate, Workspace}

  test "zero is a confirmed free-delivery fee, whereas an unlisted area has no quoted fee" do
    shop = %Workspace{
      delivery_enabled: true,
      delivery_quote_outside: true,
      delivery_rates: [%DeliveryRate{id: "zone", area: "CBD", fee: Decimal.new("0")}]
    }

    assert {:ok, free} = Fulfillment.build_quote(shop, "zone")
    assert free["fee"] == "0"
    assert {:ok, unquoted} = Fulfillment.build_quote(shop, "other")
    assert is_nil(unquoted["fee"])
    assert Fulfillment.summary(unquoted) =~ "to be confirmed"
    refute Fulfillment.valid?(shop, free)

    ready =
      free |> Map.put("awaiting_address", false) |> Map.put("address", "Shop 12, Kimathi Street")

    assert Fulfillment.valid?(shop, ready)

    changed = %{
      shop
      | delivery_rates: [%DeliveryRate{id: "zone", area: "CBD", fee: Decimal.new("150")}]
    }

    refute Fulfillment.valid?(changed, ready)
  end

  test "disabled delivery and missing pickup address never produce an executable choice" do
    shop = %Workspace{pickup_enabled: true, delivery_enabled: false, location: nil}
    assert {:error, :unavailable} = Fulfillment.build_quote(shop, "pickup")
    assert {:error, :unavailable} = Fulfillment.build_quote(shop, "other")
    assert {:error, :unavailable} = Fulfillment.build_quote(shop, "invented-zone")
  end

  test "delivery fees reject negative and sub-cent amounts without losing the area" do
    for fee <- ["-1", "12.345"] do
      changeset = DeliveryRate.changeset(%DeliveryRate{}, %{"area" => "CBD", "fee" => fee})
      refute changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :area) == "CBD"
    end

    refute DeliveryRate.changeset(%DeliveryRate{area: "CBD"}, %{"area" => ""}).valid?
  end
end
