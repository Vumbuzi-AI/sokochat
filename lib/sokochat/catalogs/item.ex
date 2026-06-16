defmodule Sokochat.Catalogs.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias Sokochat.Catalogs.Catalog

  @statuses ~w(active draft archived)
  @sources ~w(manual api import)

  schema "catalog_items" do
    belongs_to :catalog, Catalog

    field :external_id, :string
    field :title, :string
    field :description, :string
    field :price, :float
    field :currency, :string
    field :image_url, :string
    field :url, :string
    field :phone_number, :string
    field :whatsapp_number, :string
    field :metadata, :map, default: %{}
    field :source, :string, default: "manual"
    field :status, :string, default: "active"
    field :sort_order, :integer, default: 0
    field :last_synced_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :catalog_id,
      :external_id,
      :title,
      :description,
      :price,
      :currency,
      :image_url,
      :url,
      :phone_number,
      :whatsapp_number,
      :metadata,
      :source,
      :status,
      :sort_order,
      :last_synced_at
    ])
    |> normalize_string_fields([
      :external_id,
      :title,
      :description,
      :currency,
      :image_url,
      :url,
      :phone_number,
      :whatsapp_number,
      :source,
      :status
    ])
    |> put_default_metadata()
    |> validate_required([:catalog_id, :title, :source, :status])
    |> validate_length(:external_id, max: 120)
    |> validate_length(:title, min: 1, max: 160)
    |> validate_length(:currency, max: 12)
    |> validate_length(:image_url, max: 2_000)
    |> validate_length(:url, max: 2_000)
    |> validate_length(:phone_number, max: 100)
    |> validate_length(:whatsapp_number, max: 100)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:source, @sources)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:catalog_id)
  end

  def statuses, do: @statuses
  def sources, do: @sources

  defp put_default_metadata(changeset) do
    if get_field(changeset, :metadata) in [nil, %{}] do
      put_change(changeset, :metadata, %{})
    else
      changeset
    end
  end

  defp normalize_string_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, &normalize_string/1)
    end)
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(value), do: value
end
