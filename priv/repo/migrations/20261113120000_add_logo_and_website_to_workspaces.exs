defmodule Sokochat.Repo.Migrations.AddLogoAndWebsiteToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :logo_url, :text
      add :website_url, :text
    end
  end
end
