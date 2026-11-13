defmodule Sokochat.Workspaces.DeliveryRate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :area, :string
    field :fee, :decimal
  end

  def changeset(rate, attrs) do
    rate
    |> cast(attrs, [:area, :fee])
    |> update_change(:area, fn value ->
      if is_binary(value), do: String.trim(value), else: value
    end)
    |> validate_required([:area, :fee])
    |> validate_length(:area, max: 80)
    |> validate_number(:fee, greater_than_or_equal_to: 0, less_than_or_equal_to: 1_000_000)
    |> validate_change(:fee, fn :fee, fee ->
      if Decimal.equal?(fee, Decimal.round(fee, 2)),
        do: [],
        else: [fee: "must have at most two decimal places"]
    end)
  end
end
