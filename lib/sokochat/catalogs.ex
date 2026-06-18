defmodule Sokochat.Catalogs do
  @moduledoc """
  The Catalogs context.

  A workspace can define a reusable catalog model, enrich it with custom fields,
  and manually curate items that the AI can use alongside JSON API data.
  """

  import Ecto.Query, warn: false

  alias Sokochat.Catalogs.{Catalog, Field, Item}
  alias Sokochat.Repo

  @canonical_item_keys ~w(
    external_id
    title
    description
    price
    currency
    image_url
    url
    phone_number
    whatsapp_number
    source
    status
    sort_order
  )

  def get_catalog(workspace_id) do
    Catalog
    |> where([catalog], catalog.workspace_id == ^workspace_id)
    |> preload([:fields, :items])
    |> Repo.one()
  end

  def get_catalog_or_new(workspace_id) do
    get_catalog(workspace_id) || %Catalog{workspace_id: workspace_id, name: "Catalog"}
  end

  def upsert_catalog(workspace_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("workspace_id", workspace_id)

    get_catalog_or_new(workspace_id)
    |> Catalog.changeset(attrs)
    |> Repo.insert_or_update()
  end

  def change_catalog(%Catalog{} = catalog, attrs \\ %{}) do
    Catalog.changeset(catalog, normalize_attrs(attrs))
  end

  def list_fields(%Catalog{} = catalog) do
    Field
    |> where([field], field.catalog_id == ^catalog.id)
    |> order_by([field], asc: field.position, asc: field.inserted_at)
    |> Repo.all()
  end

  def list_items(%Catalog{} = catalog) do
    Item
    |> where([item], item.catalog_id == ^catalog.id)
    |> order_by([item], asc: item.sort_order, desc: item.inserted_at)
    |> Repo.all()
  end

  def get_item!(catalog_id, item_id) do
    Repo.get_by!(Item, catalog_id: catalog_id, id: item_id)
  end

  def get_field!(catalog_id, field_id) do
    Repo.get_by!(Field, catalog_id: catalog_id, id: field_id)
  end

  def change_field(%Field{} = field, attrs \\ %{}) do
    Field.changeset(field, attrs |> normalize_attrs() |> put_field_label())
  end

  def upsert_field(%Catalog{} = catalog, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> put_field_label()
      |> Map.put("catalog_id", catalog.id)

    case blank_to_nil(Map.get(attrs, "id")) do
      nil ->
        attrs = Map.put_new(attrs, "position", next_field_position(catalog.id))

        %Field{}
        |> Field.changeset(attrs)
        |> Repo.insert()

      id ->
        get_field!(catalog.id, normalize_id(id))
        |> Field.changeset(attrs)
        |> Repo.update()
    end
  end

  def delete_field(%Field{} = field), do: Repo.delete(field)

  def change_item(%Item{} = item, attrs \\ %{}) do
    attrs = attrs |> normalize_attrs() |> normalize_item_attrs()
    Item.changeset(item, attrs)
  end

  def upsert_item(%Catalog{} = catalog, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> normalize_item_attrs()
      |> Map.put("catalog_id", catalog.id)

    case Map.get(attrs, "id") do
      nil ->
        %Item{}
        |> Item.changeset(attrs)
        |> Repo.insert()
        |> maybe_enqueue_embedding()

      id ->
        get_item!(catalog.id, normalize_id(id))
        |> Item.changeset(attrs)
        |> Repo.update()
        |> maybe_enqueue_embedding()
    end
  end

  # Refresh the item's semantic-search embedding out of band. The worker no-ops
  # when the embedded text is unchanged, so this is cheap on every save.
  defp maybe_enqueue_embedding({:ok, %Item{} = item} = result) do
    _ = Sokochat.Workers.EmbedCatalogItem.enqueue(item.id)
    result
  end

  defp maybe_enqueue_embedding(result), do: result

  def delete_item(%Item{} = item), do: Repo.delete(item)

  @doc """
  Builds the business context the assistant reads for a workspace.

  Only the active `data_source` ("manual" or "api") contributes — the other
  source is ignored entirely so the AI never mixes the two.
  """
  def build_workspace_context(workspace_id, api_data \\ nil, data_source \\ "manual")

  def build_workspace_context(_workspace_id, api_data, "api") do
    %{}
    |> maybe_put("api_data", api_data)
  end

  def build_workspace_context(workspace_id, _api_data, _data_source) do
    case get_catalog(workspace_id) do
      nil -> %{}
      %Catalog{} = catalog -> maybe_put(%{}, "catalog", catalog_context(catalog))
    end
  end

  def catalog_configured?(workspace_id) do
    Repo.exists?(from(catalog in Catalog, where: catalog.workspace_id == ^workspace_id))
  end

  @doc """
  Distinct, non-empty item categories for a workspace, computed in the database.

  RAG retrieval only surfaces a slice of items per message, so the AI still needs
  the *complete* category list to offer browsing. This stays cheap at any catalog
  size because it's a `SELECT DISTINCT` of one JSON field.
  """
  def list_item_categories(workspace_id) do
    Item
    |> join(:inner, [i], c in Catalog, on: c.id == i.catalog_id)
    |> where([i, c], c.workspace_id == ^workspace_id)
    |> select([i], fragment("?->>'category'", i.metadata))
    |> distinct(true)
    |> Repo.all()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.sort_by(&String.downcase/1)
  end

  def item_context(%Item{} = item) do
    item
    |> item_canonical_map()
    |> Map.merge(item.metadata || %{})
  end

  def field_input_type(%Field{field_type: field_type}), do: field_input_type(field_type)
  def field_input_type("text"), do: :text
  def field_input_type("textarea"), do: :textarea
  def field_input_type("number"), do: :number
  def field_input_type("url"), do: :url
  def field_input_type("image_url"), do: :url
  def field_input_type("boolean"), do: :checkbox
  def field_input_type("json"), do: :textarea
  def field_input_type(_), do: :text

  def canonical_item_keys, do: @canonical_item_keys

  defp catalog_context(nil), do: nil

  defp catalog_context(%Catalog{} = catalog) do
    %{
      "name" => catalog.name,
      "entity_label" => catalog.entity_label,
      "context_notes" => catalog.context_notes,
      "fields" => Enum.map(catalog.fields || [], &field_context/1),
      "items" => Enum.map(catalog.items || [], &item_context/1)
    }
  end

  defp field_context(%Field{} = field) do
    %{
      "id" => field.id,
      "key" => field.key,
      "label" => field.label,
      "field_type" => field.field_type,
      "required" => field.required,
      "help_text" => field.help_text,
      "position" => field.position
    }
  end

  defp item_canonical_map(%Item{} = item) do
    %{
      "id" => item.id,
      "external_id" => item.external_id,
      "title" => item.title,
      "description" => item.description,
      "price" => item.price,
      "currency" => item.currency,
      "image_url" => item.image_url,
      "url" => item.url,
      "phone_number" => item.phone_number,
      "whatsapp_number" => item.whatsapp_number,
      "source" => item.source,
      "status" => item.status,
      "sort_order" => item.sort_order,
      "last_synced_at" => item.last_synced_at
    }
  end

  defp next_field_position(catalog_id) do
    from(field in Field,
      where: field.catalog_id == ^catalog_id,
      select: max(field.position)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      max_position -> max_position + 1
    end
  end

  defp normalize_item_attrs(attrs) do
    attrs
    |> normalize_optional_blanks(@canonical_item_keys ++ ["metadata", "last_synced_at", "id"])
    |> maybe_extract_metadata()
  end

  defp normalize_optional_blanks(attrs, keys) do
    Enum.reduce(keys, attrs, fn key, acc ->
      case Map.get(acc, key) do
        "" -> Map.put(acc, key, nil)
        _ -> acc
      end
    end)
  end

  defp maybe_extract_metadata(attrs) do
    metadata =
      attrs
      |> Map.get("metadata", %{})
      |> case do
        value when is_map(value) -> value
        _ -> %{}
      end

    {canonical, extra} =
      Enum.split_with(attrs, fn {key, _value} ->
        key in @canonical_item_keys or key in ["metadata", "catalog_id", "id"]
      end)

    metadata =
      metadata
      |> Map.merge(Map.new(extra))
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    canonical
    |> Map.new()
    |> Map.put_new("metadata", metadata)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  # The label shown to shop owners is derived from the snake_case key so they
  # only ever fill in one identifier (e.g. "stock_status" -> "Stock Status").
  defp put_field_label(attrs) do
    case blank_to_nil(Map.get(attrs, "key")) do
      nil -> attrs
      key -> Map.put(attrs, "label", humanize_key(key))
    end
  end

  defp humanize_key(key) do
    key
    |> to_string()
    |> String.replace(~r/[_-]+/, " ")
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end

  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> id
    end
  end

  defp normalize_id(id), do: id
end
