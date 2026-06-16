defmodule Sokochat.Catalogs.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Catalogs.{Field, Item}
  alias Sokochat.Workspaces.Workspace

  schema "catalogs" do
    belongs_to :workspace, Workspace

    field :name, :string
    field :entity_label, :string, default: "item"
    field :context_notes, :string

    has_many :fields, Field
    has_many :items, Item

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:workspace_id, :name, :entity_label, :context_notes])
    |> validate_required([:workspace_id, :name, :entity_label])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:entity_label, min: 2, max: 80)
    |> validate_length(:context_notes, max: 5_000)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint(:workspace_id)
  end
end
