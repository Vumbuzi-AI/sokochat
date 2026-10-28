defmodule Sokochat.Repo.Migrations.AddCategoriesToCatalogs do
  use Ecto.Migration

  def change do
    alter table(:catalogs) do
      add :categories, {:array, :string}, null: false, default: []
    end

    execute(
      """
      UPDATE catalogs
      SET categories = (
        SELECT COALESCE(array_agg(DISTINCT metadata->>'category' ORDER BY metadata->>'category'), ARRAY[]::varchar[])
        FROM catalog_items
        WHERE catalog_items.catalog_id = catalogs.id
          AND metadata->>'category' IS NOT NULL
          AND metadata->>'category' <> ''
      )
      """,
      "UPDATE catalogs SET categories = ARRAY[]::varchar[]"
    )

    execute(
      "DELETE FROM catalog_fields WHERE key = 'category'",
      "SELECT 1"
    )
  end
end
