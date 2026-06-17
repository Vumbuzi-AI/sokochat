defmodule Sokochat.Repo.Migrations.AddDataSourceToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :data_source, :string, null: false, default: "manual"
    end
  end
end
