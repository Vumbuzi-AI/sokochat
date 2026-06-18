defmodule Sokochat.Workers.EmbedCatalogItem do
  @moduledoc """
  Generates and stores the semantic-search embedding for a single catalog item.

  Enqueued whenever an item is created/updated, and by the backfill task for
  items that have no embedding yet. Skips work when the source text is unchanged
  (matched against `embedding_source_hash`), so editing unrelated fields or
  re-running a backfill costs nothing.

  Oban uniqueness keyed on the item id collapses rapid successive edits into a
  single embed.
  """

  use Oban.Worker,
    queue: :embeddings,
    max_attempts: 5,
    unique: [keys: [:item_id], period: 60]

  import Ecto.Query

  alias Sokochat.AI.Embedder
  alias Sokochat.AI.Retriever
  alias Sokochat.Catalogs.Item
  alias Sokochat.Repo

  require Logger

  @doc "Enqueue an embedding refresh for the given item id."
  def enqueue(item_id) do
    %{item_id: item_id}
    |> new()
    |> Oban.insert()
  end

  @doc """
  Enqueue embedding jobs for every active item in `workspace_id` that is missing
  an embedding. Returns the number of jobs inserted.
  """
  def backfill_workspace(workspace_id) do
    Item
    |> join(:inner, [i], c in assoc(i, :catalog))
    |> where([i, c], c.workspace_id == ^workspace_id)
    |> where([i], is_nil(i.embedding))
    |> select([i], i.id)
    |> Repo.all()
    |> Enum.map(&enqueue/1)
    |> Enum.count(&match?({:ok, _}, &1))
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    case Repo.get(Item, item_id) do
      nil ->
        # Item was deleted between enqueue and execution; nothing to do.
        :ok

      %Item{} = item ->
        embed_item(item)
    end
  end

  defp embed_item(item) do
    text = Retriever.embedding_text(item)
    hash = :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)

    if hash == item.embedding_source_hash do
      :ok
    else
      with {:ok, vector} <- Embedder.embed(text) do
        item
        |> Ecto.Changeset.change(
          embedding: vector,
          embedding_source_hash: hash,
          embedded_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()
        |> case do
          {:ok, _item} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
