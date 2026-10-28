defmodule Sokochat.Conversations.AiTurn do
  use Ecto.Schema

  schema "ai_turns" do
    field :workspace_id, :id
    field :conversation_id, :id
    field :user_message_id, :id
    field :assistant_message_id, :id
    field :source_key, :string
    field :instructions, :string
    field :tool_mode, :string, default: "context"
    field :payload, :map
    field :status, :string, default: "queued"
    field :last_error, :string
    field :delivery_status, :string, default: "none"
    field :delivery_index, :integer, default: 0
    field :provider_message_ids, {:array, :string}, default: []
    timestamps(type: :utc_datetime)
  end
end
