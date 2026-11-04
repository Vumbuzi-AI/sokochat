defmodule Sokochat.Repo.Migrations.CreateSharedLines do
  use Ecto.Migration

  def change do
    create table(:shared_lines) do
      add :account_id, references(:users, on_delete: :delete_all), null: false
      add :phone_number_id, :string, null: false
      add :waba_id, :string, null: false
      add :access_token_encrypted, :binary, null: false
      add :verify_token, :string, null: false
      add :display_phone, :string, null: false
      add :webhook_verified_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :last_error, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shared_lines, [:account_id])
    create index(:shared_lines, [:phone_number_id])

    alter table(:workspaces) do
      add :shared_line_id, references(:shared_lines, on_delete: :nilify_all)
      add :shop_code, :string
    end

    create unique_index(:workspaces, [:shared_line_id, :shop_code],
             where: "shared_line_id IS NOT NULL AND shop_code IS NOT NULL"
           )

    create table(:shop_bindings) do
      add :shared_line_id, references(:shared_lines, on_delete: :delete_all), null: false
      add :phone_number, :string, null: false
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shop_bindings, [:shared_line_id, :phone_number])
    create index(:shop_bindings, [:workspace_id])
  end
end
