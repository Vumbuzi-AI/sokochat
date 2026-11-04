defmodule Sokochat.Meta.ShopBinding do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Meta.SharedLine
  alias Sokochat.Workspaces.Workspace

  schema "shop_bindings" do
    belongs_to :shared_line, SharedLine
    belongs_to :workspace, Workspace

    field :phone_number, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(binding, attrs) do
    binding
    |> cast(attrs, [:shared_line_id, :phone_number, :workspace_id])
    |> validate_required([:shared_line_id, :phone_number, :workspace_id])
    |> validate_length(:phone_number, min: 2, max: 100)
    |> foreign_key_constraint(:shared_line_id)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint([:shared_line_id, :phone_number])
  end
end
