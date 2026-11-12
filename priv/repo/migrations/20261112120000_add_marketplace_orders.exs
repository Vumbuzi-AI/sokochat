defmodule Sokochat.Repo.Migrations.AddMarketplaceOrders do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :marketplace, :boolean, null: false, default: false
    end

    create unique_index(:workspaces, [:shared_line_id],
             where: "marketplace = true",
             name: :one_marketplace_per_line
           )

    create table(:order_requests) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :shared_line_id, references(:shared_lines, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :nilify_all)
      add :item_id, references(:catalog_items, on_delete: :nilify_all)
      add :phone_number, :string, null: false
      add :source_key, :string, null: false
      add :product, :map, null: false
      add :status, :string, null: false, default: "draft"
      add :requested_at, :utc_datetime
      add :contacted_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:order_requests, [:shared_line_id, :source_key])
    create index(:order_requests, [:workspace_id, :status, :requested_at])

    create constraint(:order_requests, :order_request_status,
             check: "status IN ('draft', 'requested', 'contacted')"
           )
  end
end
