defmodule Sokochat.Repo.Migrations.AddFixedReplyToAiTurns do
  use Ecto.Migration

  def change do
    alter table(:ai_turns) do
      add :fixed_reply, :map
    end
  end
end
