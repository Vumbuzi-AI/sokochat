defmodule Sokochat.Marketplace.OrderRequest do
  use Ecto.Schema

  schema "order_requests" do
    belongs_to :workspace, Sokochat.Workspaces.Workspace
    belongs_to :shared_line, Sokochat.Meta.SharedLine
    belongs_to :conversation, Sokochat.Conversations.Conversation
    belongs_to :item, Sokochat.Catalogs.Item
    field :phone_number, :string
    field :source_key, :string
    field :product, :map
    field :fulfillment, :map
    field :status, :string, default: "draft"
    field :requested_at, :utc_datetime
    field :contacted_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
