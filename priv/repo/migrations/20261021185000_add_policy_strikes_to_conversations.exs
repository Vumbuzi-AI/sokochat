defmodule Sokochat.Repo.Migrations.AddPolicyStrikesToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :policy_strikes, :integer, null: false, default: 0
    end
  end
end
