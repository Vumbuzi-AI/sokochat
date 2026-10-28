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
    field :categories, {:array, :string}, default: []

    has_many :fields, Field
    has_many :items, Item

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [:workspace_id, :name, :entity_label, :context_notes, :categories])
    |> update_change(:categories, &normalize_categories/1)
    |> validate_required([:workspace_id, :name, :entity_label])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:entity_label, min: 2, max: 80)
    |> validate_length(:context_notes, max: 5_000)
    |> validate_length(:categories, max: 80)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint(:workspace_id)
  end

  defp normalize_categories(categories) when is_list(categories) do
    categories
    |> Enum.map(&normalize_category/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp normalize_categories(_), do: []

  defp normalize_category(value) when is_binary(value) do
    name = value |> String.trim() |> String.replace(~r/\s+/, " ")
    if name == "", do: nil, else: name
  end

  defp normalize_category(_), do: nil
end
