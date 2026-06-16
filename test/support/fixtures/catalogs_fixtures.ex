defmodule Sokochat.CatalogsFixtures do
  @moduledoc """
  Test helpers for creating catalog entities via the `Sokochat.Catalogs` context.
  """

  def valid_catalog_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Product catalog",
      entity_label: "item",
      context_notes: "Use this catalog to answer buyer questions about inventory."
    })
  end

  def catalog_fixture(workspace, attrs \\ %{}) do
    {:ok, catalog} =
      Sokochat.Catalogs.upsert_catalog(workspace.id, valid_catalog_attributes(attrs))

    catalog
  end

  def valid_field_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      key: "size",
      label: "Size",
      field_type: "text",
      required: false,
      help_text: "Available sizes"
    })
  end

  def field_fixture(catalog, attrs \\ %{}) do
    {:ok, field} =
      Sokochat.Catalogs.upsert_field(catalog, valid_field_attributes(attrs))

    field
  end

  def valid_item_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Classic Hoodie",
      description: "A warm hoodie for cold evenings.",
      price: 39.99,
      currency: "USD",
      image_url: "https://images.example.com/hoodie.jpg",
      url: "https://shop.example.com/products/classic-hoodie",
      metadata: %{"color" => "Navy"},
      source: "manual",
      status: "active"
    })
  end

  def item_fixture(catalog, attrs \\ %{}) do
    {:ok, item} =
      Sokochat.Catalogs.upsert_item(catalog, valid_item_attributes(attrs))

    item
  end
end
