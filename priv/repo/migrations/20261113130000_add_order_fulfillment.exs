defmodule Sokochat.Repo.Migrations.AddOrderFulfillment do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :pickup_enabled, :boolean, default: false, null: false
      add :opening_hours, :text
      add :map_url, :text
      add :delivery_enabled, :boolean, default: false, null: false
      add :delivery_quote_outside, :boolean, default: true, null: false
      add :delivery_rates, :map, default: fragment("'[]'::jsonb"), null: false
    end

    alter table(:order_requests) do
      add :fulfillment, :map
    end
  end
end
