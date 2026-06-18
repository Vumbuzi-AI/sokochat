defmodule Sokochat.Repo.Migrations.AddEmbeddingsToCatalogItems do
  use Ecto.Migration

  # Dimensions of the configured embedding model (text-embedding-3-small).
  # Keep in sync with config :sokochat, :embeddings, dimensions: ...
  @dimensions 1536

  def up do
    # Requires the pgvector extension to be installed in the database server
    # (e.g. `brew install pgvector` for Homebrew Postgres). Safe to re-run.
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    alter table(:catalog_items) do
      add :embedding, :"vector(#{@dimensions})"
      # Hash of the text the embedding was generated from, so we only re-embed
      # when the source content actually changes.
      add :embedding_source_hash, :string
      add :embedded_at, :utc_datetime
    end

    # IVFFlat index for fast approximate cosine-distance search. `lists` is a
    # tuning knob; ~sqrt(rows) is a reasonable starting point for small sets.
    execute """
    CREATE INDEX catalog_items_embedding_idx
    ON catalog_items
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS catalog_items_embedding_idx"

    alter table(:catalog_items) do
      remove :embedding
      remove :embedding_source_hash
      remove :embedded_at
    end
  end
end
