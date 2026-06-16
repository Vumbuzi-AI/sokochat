defmodule Sokochat.Repo.Migrations.CreateCatalogs do
  use Ecto.Migration

  def change do
    create table(:catalogs) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :entity_label, :string, null: false, default: "item"
      add :context_notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:catalogs, [:workspace_id])

    create table(:catalog_fields) do
      add :catalog_id, references(:catalogs, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :label, :string, null: false
      add :field_type, :string, null: false, default: "text"
      add :required, :boolean, null: false, default: false
      add :help_text, :string
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:catalog_fields, [:catalog_id, :key])
    create index(:catalog_fields, [:catalog_id, :position])

    create table(:catalog_items) do
      add :catalog_id, references(:catalogs, on_delete: :delete_all), null: false
      add :external_id, :string
      add :title, :string, null: false
      add :description, :text
      add :price, :float
      add :currency, :string
      add :image_url, :string
      add :url, :string
      add :phone_number, :string
      add :whatsapp_number, :string
      add :metadata, :map, null: false, default: %{}
      add :source, :string, null: false, default: "manual"
      add :status, :string, null: false, default: "active"
      add :sort_order, :integer, null: false, default: 0
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:catalog_items, [:catalog_id, :status])
    create index(:catalog_items, [:catalog_id, :sort_order])
    create index(:catalog_items, [:catalog_id, :inserted_at])
  end
end
