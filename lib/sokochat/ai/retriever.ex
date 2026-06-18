defmodule Sokochat.AI.Retriever do
  @moduledoc """
  Semantic retrieval (the "R" in RAG) over a workspace's catalog items.

  Instead of dumping a whole catalog into the prompt, we embed the buyer's
  message and pull only the most relevant items via pgvector cosine distance.
  This keeps the prompt a constant size no matter how large the catalog is.
  """

  import Ecto.Query

  alias Sokochat.AI.Embedder
  alias Sokochat.Catalogs
  alias Sokochat.Catalogs.{Catalog, Item}
  alias Sokochat.Repo

  @default_k 12

  @doc """
  Returns up to `k` catalog item context maps for `workspace_id` most relevant
  to `query`, ordered by similarity. Falls back to recency when the query can't
  be embedded or no items are indexed yet, so the bot is never left blind.
  """
  def search(workspace_id, query, opts \\ []) when is_binary(query) do
    k = Keyword.get(opts, :k, @default_k)

    case Embedder.embed(query) do
      {:ok, vector} ->
        items = nearest_items(workspace_id, vector, k)
        if items == [], do: fallback_items(workspace_id, k), else: items

      {:error, _reason} ->
        fallback_items(workspace_id, k)
    end
    |> Enum.map(&Catalogs.item_context/1)
  end

  @doc """
  The canonical text we embed for an item. Used both when indexing items and as
  the source for the staleness hash, so the two never drift apart.
  """
  def embedding_text(%Item{} = item) do
    [
      item.title,
      item.description,
      category_of(item),
      currency_price(item)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  defp nearest_items(workspace_id, vector, k) do
    Item
    |> join(:inner, [i], c in Catalog, on: c.id == i.catalog_id)
    |> where([i, c], c.workspace_id == ^workspace_id)
    |> where([i], not is_nil(i.embedding))
    |> where([i], i.status == "active")
    |> order_by([i], asc: fragment("? <=> ?", i.embedding, ^vector))
    |> limit(^k)
    |> Repo.all()
  end

  defp fallback_items(workspace_id, k) do
    Item
    |> join(:inner, [i], c in Catalog, on: c.id == i.catalog_id)
    |> where([i, c], c.workspace_id == ^workspace_id)
    |> where([i], i.status == "active")
    |> order_by([i], asc: i.sort_order, desc: i.inserted_at)
    |> limit(^k)
    |> Repo.all()
  end

  defp category_of(%Item{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, "category") || Map.get(metadata, :category)
  end

  defp category_of(_item), do: nil

  defp currency_price(%Item{price: nil}), do: nil
  defp currency_price(%Item{price: price, currency: currency}), do: "#{currency} #{price}"
end
