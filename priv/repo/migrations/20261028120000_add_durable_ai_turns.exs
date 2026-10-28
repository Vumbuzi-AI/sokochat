defmodule Sokochat.Repo.Migrations.AddDurableAiTurns do
  use Ecto.Migration

  def change do
    create table(:ai_turns) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_message_id, references(:messages, on_delete: :delete_all), null: false
      add :assistant_message_id, references(:messages, on_delete: :nilify_all)
      add :source_key, :string
      add :instructions, :text, null: false
      add :tool_mode, :string, null: false, default: "context"
      add :payload, :map
      add :status, :string, null: false, default: "queued"
      add :last_error, :text
      add :delivery_status, :string, null: false, default: "none"
      add :delivery_index, :integer, null: false, default: 0
      add :provider_message_ids, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime)
    end

    create unique_index(:ai_turns, [:user_message_id])
    create unique_index(:ai_turns, [:workspace_id, :source_key])
    create index(:ai_turns, [:conversation_id, :status, :id])
    create index(:ai_turns, [:delivery_status])

    create constraint(:ai_turns, :ai_turn_state,
             check: "status IN ('queued', 'completed', 'failed')"
           )

    create constraint(:ai_turns, :ai_delivery_state,
             check: "delivery_status IN ('none', 'pending', 'sending', 'sent', 'uncertain')"
           )
  end
end
