# SokoChat — System Architecture

> **Vision:** SokoChat lets any business connect with its customers over WhatsApp
> and *do it all* — answer questions from live business data, sell products, issue
> event tickets, take payments, book appointments, and follow up on leads — through
> one AI assistant that pulls the right context dynamically.

---

## 1. Current pipeline

```
WhatsApp ─▶ webhook_controller ─▶ Oban (ProcessInboundMessage)
                                        │
                                  Dispatcher.dispatch
                                        │
          ┌─────────────────────────────┼─────────────────────────────┐
     Endpoints (API/cached)      Catalogs (manual items)        CTA rules
          └──────────────► context for the message ◄────────────┘
                                        │
                          ContextBuilder.build_system_prompt
                                        │
                              OpenAIClient (Responses API,
                              structured reply + CTA schema)
                                        │
                          Conversations (messages persisted) ─▶ Sender ─▶ WhatsApp
```

**Key modules**

| Concern | Module |
| --- | --- |
| Inbound orchestration | `Sokochat.Conversations.Dispatcher` |
| Prompt assembly | `Sokochat.AI.ContextBuilder` |
| LLM call | `Sokochat.AI.OpenAIClient` (Responses API, JSON-schema output) |
| Data: manual catalog | `Sokochat.Catalogs` (`Catalog`, `Field`, `Item`) |
| Data: external JSON API | `Sokochat.Endpoints` |
| Channel I/O | `Sokochat.Meta` / `Sokochat.Meta.Sender` |
| Persistence | `Sokochat.Conversations` (`Conversation`, `Message`) |

---

## 2. The three-layer target architecture

Each layer is a clean extension of what already exists.

### Layer 1 — Dynamic context via RAG  ✅ *(implemented — see §3)*
Stop putting *data* in the prompt; put *capabilities* in the prompt and let the
assistant **retrieve** the relevant data per message. This is what makes context
scale from 10 records to 100,000 without changing prompt size.

### Layer 2 — Tools / actions  *(designed, not yet built)*
Move the LLM call from "return a reply + presentational CTA" to **function
calling**, so the assistant can *do* things mid-conversation, not just describe
them. A registry of action modules — each a behaviour with an input schema and a
`run/2` — is exposed to the model. A workspace enables the subset it needs.

| Tool | Purpose |
| --- | --- |
| `search_catalog(query, filters)` | the RAG retrieval below, on demand |
| `check_availability(item_id)` | live stock / seat count |
| `create_order(items, contact)` | build a cart / order |
| `create_ticket(event_id, qty)` | event tickets |
| `initiate_payment(order_id)` | pay link / M-Pesa STK push |
| `book_slot(service, time)` | appointments |
| `handoff_to_human()` | escalate |

This replaces the hand-maintained "RULES" prose about CTAs — the schema *is* the
contract — and is how one engine serves a shop, an event organizer, and a clinic.

### Layer 3 — Payments + CRM / leads  *(designed, not yet built)*
- **Payments** = just another action provider, behind a `Payments.Provider`
  behaviour. First targets: **M-Pesa (Daraja STK push)** and **Stripe**, both
  behind the same behaviour so `initiate_payment` is provider-agnostic.
  Persist `orders` + `payments`; reconcile via provider webhooks.
- **CRM / leads** builds on the messages we already persist:
  - `contacts` — the person (one per phone number per workspace).
  - `leads` — `stage` (new → engaged → quoted → won/lost) + `last_activity_at`.
  - `events` — append-only timeline (`message_received`, `order_created`,
    `payment_completed`, `cart_abandoned`) powering follow-ups.
  - **Follow-up worker** — Oban-scheduled; nudges idle leads with an open intent.
    (Subject to WhatsApp's 24h window — re-engagement needs approved templates.)

---

## 3. RAG context layer (implemented)

### Why
`ContextBuilder` previously `Jason.encode!`'d the **entire** dataset and truncated
at 3,000 chars, with a keyword-matching `detect_focus_category/2` patch over the
top. At ~1,000 records this either blows the context window or truncates away the
product the buyer actually wants. RAG fixes this at the root.

### How it works now
```
buyer msg ─▶ Retriever.search(workspace_id, msg, k: 12)
                 │  embed msg → pgvector cosine top-K over the workspace's items
                 ▼
        ContextBuilder.build_system_prompt(workspace, retrieved_slice,
                                            all_categories: [...])
```
Prompt size is now **constant** regardless of catalog size, and the assistant
always sees the most relevant items. The full category list is still passed
explicitly (a cheap `SELECT DISTINCT`) so "what do you have?" browsing stays
complete even though only a slice of items is retrieved.

### Components added

| Piece | Location |
| --- | --- |
| Vector storage | `catalog_items.embedding vector(1536)` + `embedding_source_hash` + `embedded_at` — migration `20260618120000_add_embeddings_to_catalog_items.exs` |
| pgvector type registration | `Sokochat.PostgrexTypes`, wired via `config :sokochat, Sokochat.Repo, types:` |
| Embeddings client | `Sokochat.AI.Embedder` (OpenAI `text-embedding-3-small`, 1536 dims) |
| Retrieval | `Sokochat.AI.Retriever` — top-K cosine search; recency fallback when a query can't be embedded or nothing is indexed yet |
| Async indexing | `Sokochat.Workers.EmbedCatalogItem` — embeds on item upsert, no-ops when source text is unchanged (hash), plus `backfill_workspace/1` |
| Category list | `Catalogs.list_item_categories/1` — DB-side distinct, stays cheap at any size |
| Wiring | `Dispatcher.system_prompt_for/2` uses RAG for `data_source: "manual"` workspaces; the `"api"` source keeps its existing behavior |

### Configuration
```elixir
# config/runtime.exs
config :sokochat, :embeddings,
  api_key: openai_api_key,
  model: System.get_env("OPENAI_EMBEDDING_MODEL") || "text-embedding-3-small",
  dimensions: 1536   # MUST match vector(N) in the migration
```

### Prerequisites & operational notes
- **pgvector must be installed in the Postgres server.** Homebrew:
  `brew install pgvector`, then `mix ecto.migrate` (the migration runs
  `CREATE EXTENSION IF NOT EXISTS vector`).
- **Backfill existing items** after migrating:
  `Sokochat.Workers.EmbedCatalogItem.backfill_workspace(workspace_id)`.
- The IVFFlat index uses `lists = 100`; tune toward `~sqrt(row_count)` as catalogs
  grow. Re-index if a workspace's item count changes by an order of magnitude.
- Embeddings run on the `:embeddings` Oban queue (concurrency 5).

### Known follow-ups
- The `:api` data source isn't embedded yet. The `Retriever` interface is written
  so an API/knowledge-chunks provider can plug in without changing callers —
  normalize-and-embed cached API JSON into a generic `knowledge_chunks` table on
  each refresh.
- The per-message `endpoint_snapshot` saved on the user message still stores the
  broad context for `:api` workspaces. For RAG workspaces, consider snapshotting
  the retrieved slice instead (smaller, and reflects what the model actually saw).

---

## 4. Suggested module layout (target)

```
lib/sokochat/
  ai/
    embedder.ex         # text → vector                      ✅
    retriever.ex        # query → pgvector top-K              ✅
    context_builder.ex  # format retrieved slice             ✅ (refactored)
    tool_runtime.ex     # tool-call loop over Responses API   ▢
  actions/
    action.ex           # behaviour                           ▢
    search_catalog.ex / create_order.ex / initiate_payment.ex ▢
  commerce/
    orders.ex / order.ex / payment.ex                         ▢
  payments/
    provider.ex / mpesa.ex / stripe.ex                        ▢
  crm/
    contacts.ex / leads.ex / events.ex / followups.ex         ▢
  workers/
    embed_catalog_item.ex                                     ✅
```

---

## 5. Build sequence

1. **RAG context** — ✅ done (this document, §3).
2. **Tool runtime** — convert the AI call to function calling; `search_catalog`
   first to prove the loop, backwards-compatible with the current CTA output.
3. **Commerce + one payment provider** — `create_order` + M-Pesa.
4. **CRM / leads + follow-up worker.**
5. **Tickets / booking** — additional action modules; nearly free once 2–4 exist.
