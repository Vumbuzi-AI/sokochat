defmodule Sokochat.Repo.Migrations.AddOrderRequestReferences do
  use Ecto.Migration

  def up do
    # A database default also covers inserts from an older application during rollout.
    execute("""
    CREATE FUNCTION sokochat_order_reference() RETURNS text AS $$
      SELECT 'SC-' || substr(code, 1, 4) || '-' || substr(code, 5, 4) || '-' || substr(code, 9, 4)
      FROM (SELECT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)) AS code) random_code
    $$ LANGUAGE SQL VOLATILE;
    """)

    alter table(:order_requests) do
      add :reference, :string, default: fragment("sokochat_order_reference()"), null: false
    end

    create unique_index(:order_requests, [:reference])

    create constraint(:order_requests, :order_request_reference_format,
             check: "reference ~ '^SC-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$'"
           )
  end

  def down do
    alter table(:order_requests) do
      remove :reference
    end

    execute("DROP FUNCTION sokochat_order_reference()")
  end
end
