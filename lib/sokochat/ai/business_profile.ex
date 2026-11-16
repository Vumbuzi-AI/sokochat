defmodule Sokochat.AI.BusinessProfile do
  @moduledoc "Public business and fulfilment facts shared by prompts and Pi tools."

  def build(workspace) do
    delivery = field(workspace, :delivery_enabled)

    Map.new(
      ~w(name company_name industry location opening_hours map_url phone_number about website_url)a,
      &{&1, field(workspace, &1)}
    )
    |> Map.merge(%{
      pickup_enabled: field(workspace, :pickup_enabled),
      delivery_enabled: delivery,
      delivery_quote_outside:
        delivery == true and field(workspace, :delivery_quote_outside) == true,
      delivery_rates:
        if(delivery == true,
          do:
            Enum.map(field(workspace, :delivery_rates) || [], fn rate ->
              %{area: field(rate, :area), fee: fee(field(rate, :fee)), currency: "KES"}
            end),
          else: []
        )
    })
  end

  defp fee(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp fee(value), do: value

  defp field(data, key), do: Map.get(data, key, Map.get(data, Atom.to_string(key)))
end
