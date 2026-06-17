defmodule Sokochat.Repo.Migrations.AddBusinessProfileToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :company_name, :string
      add :industry, :string
      add :location, :text
      add :phone_number, :string
      add :about, :text
    end
  end
end
